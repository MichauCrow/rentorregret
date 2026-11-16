-- Mechanik: w aucie świecą zepsute części. Przytrzymaj "Napraw" przy części i wybierz właściwe narzędzie.
-- Gdy auto jest naprawione, wjeżdża następne. Punkt za każdą naprawioną część.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local PropBuilder = require(ServerScriptService.World.PropBuilder)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local JobService = require(Services.JobService)

local MechanicJob = {
	JobId = "mechanic",
}

local CONFIG = JobsConfig.Jobs.mechanic
local NEXT_CAR_DELAY = 1.5
local ANSWER_INTERVAL = 0.3

local carSpot = nil
local rng = Random.new()

local function toolOptions()
	local options = {}
	for _, tool in CONFIG.tools do
		table.insert(options, { value = tool.id, label = tool.label })
	end
	return options
end

local function report(session, extra)
	local state = session.state
	local hint = if state.brokenLeft > 0
		then string.format("Usterki w aucie: %d (świecą na czerwono)", state.brokenLeft)
		else "Auto naprawione! Za chwilę wjedzie następne"
	JobService.UpdateProgress(session, state.fixed, state.goal, hint, extra)
end

local function toolChoice(session, key: string, mistake: boolean)
	return {
		mode = "choice",
		action = "tool",
		title = "Naprawa: " .. CONFIG.parts[key].name,
		prompt = if mistake then "To nie to narzędzie! Spróbuj jeszcze raz" else "Jakiego narzędzia użyć?",
		options = toolOptions(),
		mistake = mistake,
	}
end

local function onInspect(session, player: Player, carPart: BasePart)
	local state = session.state
	if player ~= session.player or not JobService.IsActive(session) or not state.broken[carPart] then
		return
	end
	state.selected = carPart
	report(session, toolChoice(session, state.broken[carPart], false))
end

local function newCar(session)
	local state = session.state
	if not JobService.IsActive(session) then
		return
	end
	if state.car then
		state.car:Destroy()
	end
	local car, repairable = PropBuilder.Car(carSpot.CFrame)
	state.car = car
	state.broken = {}
	state.selected = nil
	for i = #repairable, 2, -1 do
		local j = rng:NextInteger(1, i)
		repairable[i], repairable[j] = repairable[j], repairable[i]
	end
	local count = rng:NextInteger(1, session.levelConfig.brokenMax)
	for i = 1, count do
		local entry = repairable[i]
		state.broken[entry.part] = entry.key
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.OutlineColor = Color3.fromRGB(255, 230, 80)
		highlight.FillTransparency = 0.35
		highlight.Parent = entry.part
		JobService.SetGuideTarget(entry.part, "🔧 Napraw")
		HoldPrompt.Create(entry.part, {
			action = "Napraw",
			object = CONFIG.parts[entry.key].name,
			hold = CONFIG.repairHold,
			activation = 8,
			maxDistance = 12,
		}, function(player)
			onInspect(session, player, entry.part)
		end)
	end
	state.brokenLeft = count
	car.Parent = session.folder
	report(session, nil)
end

function MechanicJob.Init()
	carSpot = Workspace.Map.JobSites:WaitForChild("Garage"):WaitForChild("CarSpot")
end

function MechanicJob.StartShift(session)
	local state = session.state
	state.goal = session.levelConfig.goal
	state.fixed = 0
	state.mistakes = 0
	state.lastAnswer = 0
	newCar(session)
end

function MechanicJob.OnAction(session, action: string, value: any)
	local state = session.state
	local carPart = state.selected
	if action ~= "tool" or not carPart or not state.broken[carPart] or not RemoteService.IsString(value, 16) then
		return
	end
	local now = os.clock()
	if now - state.lastAnswer < ANSWER_INTERVAL then
		return
	end
	state.lastAnswer = now
	local key = state.broken[carPart]
	if value ~= CONFIG.parts[key].tool then
		state.mistakes += 1
		report(session, toolChoice(session, key, true))
		return
	end

	state.broken[carPart] = nil
	JobService.SetGuideTarget(carPart, nil)
	state.selected = nil
	state.fixed += 1
	state.brokenLeft -= 1
	for _, child in carPart:GetChildren() do
		if child:IsA("Highlight") or child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(session.player, carPart.Position, "repair", 1)
	report(session, nil)
	if state.brokenLeft <= 0 then
		task.delay(NEXT_CAR_DELAY, newCar, session)
	end
end

function MechanicJob.Evaluate(session): number
	local state = session.state
	return JobService.StarsFromFraction(state.fixed / state.goal)
end

return MechanicJob

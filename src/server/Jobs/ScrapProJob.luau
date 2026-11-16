-- Łowca złomu PRO: przeszukaj stertę złomu, napraw znalezisko (wybór części) i sprzedaj je w budce.
-- Wypłata jest mnożona przez cenę złomu dnia (taka sama dla wszystkich graczy danego dnia).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local PropBuilder = require(ServerScriptService.World.PropBuilder)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local StateService = require(Services.StateService)
local JobService = require(Services.JobService)

local ScrapProJob = {
	JobId = "scrapPro",
}

local CONFIG = JobsConfig.Jobs.scrapPro
local ANSWER_INTERVAL = 0.3
local SECONDS_PER_DAY = 86400

local area = nil
local bucket = nil -- kubeł Pana Złomka (miejsce sprzedaży)
local bubble = nil
local bubbleToken = 0
local rng = Random.new()

-- Pan Złomek na chwilę zmienia napis w dymku
local function say(text: string)
	if not bubble then
		return
	end
	bubbleToken += 1
	local token = bubbleToken
	bubble.Text = text
	task.delay(2, function()
		if token == bubbleToken then
			bubble.Text = "Pan Złomek 💰"
		end
	end)
end

local function fixOptions()
	local options = {}
	for _, fix in CONFIG.fixes do
		table.insert(options, { value = fix.id, label = fix.label })
	end
	return options
end

-- Cena dnia liczona z numeru dnia, więc jest identyczna na wszystkich serwerach
function ScrapProJob.GetDayPrice(): number
	local day = math.floor(os.time() / SECONDS_PER_DAY)
	return Random.new(day * 7919 + 13):NextNumber(CONFIG.priceMin, CONFIG.priceMax)
end

local function report(session, hint: string, extra)
	local state = session.state
	local priceText = string.format("Cena złomu dziś: %d%%", math.floor(state.price * 100 + 0.5))
	-- Przewodnik: do stert, gdy nic nie niesiesz; do Pana Złomka, gdy znalezisko jest naprawione
	if session.folder then
		for _, child in session.folder:GetChildren() do
			if child.Name == "ScrapPile" then
				JobService.SetGuideTarget(child, if not state.item then "🔍 Przeszukaj" else nil)
			end
		end
	end
	if state.sellPoint then
		JobService.SetGuideTarget(state.sellPoint, if state.item and state.repaired then "💰 Sprzedaj" else nil)
	end
	JobService.UpdateProgress(session, state.sold, state.goal, hint .. "\n" .. priceText, extra)
end

local function fixChoice(item, mistake: boolean)
	return {
		mode = "choice",
		action = "fix",
		title = "Znalezisko: " .. item.name,
		prompt = if mistake then "To nie to! Co trzeba wymienić?" else "Co trzeba wymienić, żeby działało?",
		options = fixOptions(),
		mistake = mistake,
	}
end

local spawnPile

local function onSearch(session, player: Player, pile: Model)
	local state = session.state
	if player ~= session.player or not JobService.IsActive(session) or not pile.Parent then
		return
	end
	if state.item then
		StateService.Notify(player, "Najpierw sprzedaj to, co masz.", "info")
		return
	end
	pile:Destroy()
	spawnPile(session)
	state.item = CONFIG.items[rng:NextInteger(1, #CONFIG.items)]
	state.repaired = false
	report(session, "Znalezisko: " .. state.item.name, fixChoice(state.item, false))
end

spawnPile = function(session)
	local position = Vector3.new(
		area.Position.X + rng:NextNumber(-area.Size.X / 2, area.Size.X / 2),
		0.3,
		area.Position.Z + rng:NextNumber(-area.Size.Z / 2, area.Size.Z / 2)
	)
	local pile = PropBuilder.ScrapPile(position)
	HoldPrompt.Create(pile.PrimaryPart, {
		action = "Przeszukaj",
		object = "Sterta złomu",
		hold = CONFIG.searchHold,
		activation = 8,
		maxDistance = 12,
	}, function(player)
		onSearch(session, player, pile)
	end)
	if not session.state.item then
		JobService.SetGuideTarget(pile, "🔍 Przeszukaj")
	end
	pile.Parent = session.folder
end

local function onSell(session, player: Player)
	local state = session.state
	if player ~= session.player or not JobService.IsActive(session) then
		return
	end
	if not state.item then
		StateService.Notify(player, "Nie masz nic do sprzedania. Przeszukaj sterty!", "info")
		return
	end
	if not state.repaired then
		StateService.Notify(player, "Najpierw napraw znalezisko.", "info")
		return
	end
	state.item = nil
	state.sold += 1
	RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, bucket.Position + Vector3.new(0, 1.5, 0), "sell", 1)
	say("Dziękuję! 😄💰")
	report(session, "Sprzedane! Szukaj dalej w stertach", nil)
end

function ScrapProJob.Init()
	local scrapyard = Workspace.Map.JobSites:WaitForChild("Scrapyard")
	area = scrapyard:WaitForChild("ScrapArea")
	local buyer = scrapyard:WaitForChild("ScrapBuyer")
	bucket = buyer:WaitForChild("Bucket")
	local head = buyer:WaitForChild("Head")
	bubble = head:WaitForChild("Bubble"):WaitForChild("Text")
end

function ScrapProJob.StartShift(session)
	local state = session.state
	state.goal = session.levelConfig.goal
	state.sold = 0
	state.mistakes = 0
	state.lastAnswer = 0
	state.price = ScrapProJob.GetDayPrice()
	for _ = 1, CONFIG.piles do
		spawnPile(session)
	end

	-- Niewidoczny punkt przy kuble Pana Złomka, w folderze sesji (inni gracze nie widzą tej podpowiedzi)
	local sellPoint = Instance.new("Part")
	sellPoint.Name = "SellPoint"
	sellPoint.Size = Vector3.new(2, 2, 2)
	sellPoint.CFrame = bucket.CFrame
	sellPoint.Transparency = 1
	sellPoint.CanCollide = false
	sellPoint.CanQuery = false
	sellPoint.Anchored = true
	HoldPrompt.Create(sellPoint, { action = "Wrzuć do kubła", object = "Pan Złomek", hold = 0.5, activation = 8, maxDistance = 12 }, function(player)
		onSell(session, player)
	end)
	sellPoint.Parent = session.folder
	state.sellPoint = sellPoint

	report(session, "Przeszukuj sterty złomu na placu", nil)
end

function ScrapProJob.OnAction(session, action: string, value: any)
	local state = session.state
	if action ~= "fix" or not state.item or state.repaired or not RemoteService.IsString(value, 16) then
		return
	end
	local now = os.clock()
	if now - state.lastAnswer < ANSWER_INTERVAL then
		return
	end
	state.lastAnswer = now
	if value == state.item.fix then
		state.repaired = true
		report(session, "Naprawione! Zanieś " .. state.item.name .. " do kubła Pana Złomka przy bramie", nil)
	else
		state.mistakes += 1
		report(session, "Znalezisko: " .. state.item.name, fixChoice(state.item, true))
	end
end

function ScrapProJob.PayFactor(session): number
	return session.state.price
end

function ScrapProJob.Evaluate(session): number
	local state = session.state
	return JobService.StarsFromFraction(state.sold / state.goal)
end

return ScrapProJob

-- Zarządza rozgrywkami: sloty kamienic daleko od holu, start rundy dla grupy z wycieraczki,
-- nagrody i statystyki po rundzie, powrót do holu, wyjścia i resety graczy w trakcie rundy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Round = require(ServerScriptService.Round.Round)
local DataService = require(script.Parent.DataService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local RoundService = {}

local slots = {} -- [nr slotu] = Round
local playerRound = {} -- [player] = Round
local lobbySpawn = CFrame.new(0, 3, -20)
local roundsFolder = nil
local nextId = 1

local function slotOrigin(index: number): Vector3
	-- Kamienice w rzędzie za holem, poza zasięgiem mgły w holu
	return Vector3.new(-750 + (index - 1) * 300, 0.5, 450)
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
		character:PivotTo(cframe)
	end
end

function RoundService.SetLobbySpawn(cframe: CFrame)
	lobbySpawn = cframe
end

function RoundService.IsInRound(player: Player): boolean
	return playerRound[player] ~= nil
end

function RoundService.HasFreeSlot(): boolean
	for index = 1, GameConfig.MAX_ROUNDS do
		if not slots[index] then
			return true
		end
	end
	return false
end

-- Wywoływane przez rundę, gdy gracz kończy (ucieczka, złapanie do końca, koniec rundy)
local function onFinished(player: Player, summary, state)
	local data = DataService.Get(player)
	if data then
		data.coins += summary.reward
		data.stats.rounds += 1
		data.stats.coinsFound += state.found
		if summary.rentPaid then
			data.stats.rentsPaid += 1
		end
		if summary.outcome == "escaped" then
			data.stats.escapes += 1
		elseif summary.outcome == "caught" then
			data.stats.caught += 1
		end
		local round = playerRound[player]
		if summary.rentPaid and round and round.paidAt then
			local seconds = math.floor(round.paidAt)
			if data.stats.bestTime == 0 or seconds < data.stats.bestTime then
				data.stats.bestTime = seconds
			end
		end
		data.tutorialDone = true
		PlayerStateService.Push(player)
	end
	-- Krótkie podsumowanie, potem powrót do holu
	local round = playerRound[player]
	task.delay(GameConfig.END_SCREEN_TIME, function()
		if playerRound[player] == round then
			playerRound[player] = nil
		end
		if player.Parent then
			teleport(player, lobbySpawn + Vector3.new(math.random(-6, 6), 0, math.random(-4, 4)))
			RemoteService.Event("RoundState"):FireClient(player, nil)
		end
	end)
end

function RoundService.StartRound(players: { Player }): boolean
	local free = nil
	for index = 1, GameConfig.MAX_ROUNDS do
		if not slots[index] then
			free = index
			break
		end
	end
	if not free then
		return false
	end
	local valid = {}
	for _, player in players do
		if player.Parent and player.Character and not playerRound[player] and DataService.Get(player) then
			table.insert(valid, player)
		end
	end
	if #valid == 0 then
		return false
	end
	local id = nextId
	nextId += 1
	local round = Round.new(id, slotOrigin(free), valid, roundsFolder, onFinished)
	round.onDestroyed = function()
		if slots[free] == round then
			slots[free] = nil
		end
	end
	slots[free] = round
	for _, player in valid do
		playerRound[player] = round
	end
	round:Start(teleport)
	return true
end

local function debugCommand(player: Player, command: any)
	if not (RunService:IsStudio() and GameConfig.DEBUG_IN_STUDIO) or type(command) ~= "string" then
		return
	end
	local round = playerRound[player]
	local data = DataService.Get(player)
	if command == "coins" and data then
		data.coins += 1000
		PlayerStateService.Push(player)
	elseif command == "reset" then
		DataService.ResetData(player)
	elseif round and command == "midnight" then
		round.timeLeft = 2
	elseif round and command == "rent" then
		round.deposited = round.rent - 1
	elseif round and command == "key" then
		round.players[player].hasKey = true
	elseif round and command == "finale" then
		round.timeLeft = GameConfig.FINALE_TIME + 1
	elseif round and command == "scare" then
		round.calm = round.nextEvent
	end
end

function RoundService.Init()
	roundsFolder = Instance.new("Folder")
	roundsFolder.Name = "Rounds"
	roundsFolder.Parent = Workspace
end

function RoundService.Start()
	RemoteService.OnServerEvent("Flashlight", 6, function(player, on)
		local round = playerRound[player]
		if round and type(on) == "boolean" then
			round:SetFlashlight(player, on)
		end
	end)
	RemoteService.OnServerEvent("GhostPing", 2, function(player)
		local round = playerRound[player]
		if round then
			round:GhostPing(player)
		end
	end)
	RemoteService.OnServerEvent("BreathResult", 2, function(player, success)
		local round = playerRound[player]
		if round and type(success) == "boolean" then
			round:BreathResult(player, success)
		end
	end)
	RemoteService.OnServerEvent("QuickChat", 2, function(player, index)
		local round = playerRound[player]
		if round and RemoteService.IsInteger(index, 1, #GameConfig.QUICK_CHAT) then
			round:QuickChat(player, index)
		end
	end)
	RemoteService.OnServerEvent("DebugCommand", 4, debugCommand)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			-- Nowa postać w trakcie rundy (reset, upadek) = koniec rundy dla gracza, pojawia się w holu
			local round = playerRound[player]
			if round then
				round:Forfeit(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local round = playerRound[player]
		playerRound[player] = nil
		if round then
			round:RemovePlayer(player)
		end
	end)
end

return RoundService

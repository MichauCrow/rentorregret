-- Hol: buduje dziedziniec i pilnuje kolejki na wycieraczce. Gdy ktoś stoi na wycieraczce, rusza
-- odliczanie; gdy dojdzie do zera, wszyscy z wycieraczki (max 4) wchodzą razem do kamienicy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local LobbyBuilder = require(ServerScriptService.World.LobbyBuilder)
local RoundService = require(script.Parent.RoundService)

local LobbyService = {}

local CHECK_INTERVAL = 0.25
local lobby = nil
local countdown = nil

local function onPad(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local pad = lobby.pad
	local offset = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(offset.X) <= pad.Size.X / 2 + 0.5 and math.abs(offset.Z) <= pad.Size.Z / 2 + 0.5 and offset.Y > -1 and offset.Y < 8
end

local function queued(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if not RoundService.IsInRound(player) and onPad(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function tick(dt: number)
	local players = queued()
	local label = lobby.padLabel
	if #players == 0 then
		countdown = nil
		label.Text = "🚪 Stań na wycieraczce, żeby wejść do kamienicy!"
		return
	end
	if not RoundService.HasFreeSlot() then
		countdown = nil
		label.Text = "⏳ Wszystkie kamienice zajęte, chwileczkę..."
		return
	end
	local count = math.min(#players, GameConfig.QUEUE_MAX_PLAYERS)
	countdown = countdown or GameConfig.QUEUE_COUNTDOWN
	if count >= GameConfig.QUEUE_MAX_PLAYERS then
		countdown = math.min(countdown, GameConfig.QUEUE_FULL_COUNTDOWN)
	end
	countdown -= dt
	label.Text = string.format("🚪 Wchodzicie: %d/%d  •  start za %d s", count, GameConfig.QUEUE_MAX_PLAYERS, math.max(0, math.ceil(countdown)))
	if countdown <= 0 then
		countdown = nil
		local group = {}
		for i = 1, count do
			group[i] = players[i]
		end
		RoundService.StartRound(group)
	end
end

function LobbyService.Init()
	lobby = LobbyBuilder.Build()
	RoundService.SetLobbySpawn(lobby.spawnCFrame)
end

function LobbyService.Start()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local ok, err = pcall(tick, CHECK_INTERVAL)
			if not ok then
				warn("[LobbyService] " .. tostring(err))
			end
		end
	end)
end

return LobbyService

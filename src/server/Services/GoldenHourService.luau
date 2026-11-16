-- Złota godzina: co kilkanaście minut na całym serwerze wypłaty i XP są podwójne przez 3 minuty.
-- Czas startu i końca leży w atrybutach ReplicatedStorage (czas serwera), klient sam odlicza i pokazuje baner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local Services = ServerScriptService.Services
local StateService = require(Services.StateService)

local GoldenHourService = {}

local CONFIG = LevelConfig.GoldenHour

local endsAt = 0
local nextAt = 0
local wakeUp = Instance.new("BindableEvent") -- budzi pętlę, gdy komenda testowa zmieni plan

local function now(): number
	return Workspace:GetServerTimeNow()
end

function GoldenHourService.IsActive(): boolean
	return now() < endsAt
end

-- Dodatek do mnożnika wypłat (JobService.GetPayMultiplier)
function GoldenHourService.PayBonus(): number
	return if GoldenHourService.IsActive() then CONFIG.payBonus else 0
end

function GoldenHourService.XpMultiplier(): number
	return if GoldenHourService.IsActive() then CONFIG.xpMultiplier else 1
end

local function publish()
	ReplicatedStorage:SetAttribute("GoldenHourEndsAt", endsAt)
	ReplicatedStorage:SetAttribute("GoldenHourNextAt", nextAt)
	ReplicatedStorage:SetAttribute("GoldenHourDuration", CONFIG.duration)
end

local function everyone(text: string, kind: string)
	for _, player in Players:GetPlayers() do
		StateService.Notify(player, text, kind)
		StateService.Push(player)
	end
end

local function waitUntil(time: number)
	while now() < time - 0.05 do
		local left = time - now()
		local woke = false
		local connection = wakeUp.Event:Once(function()
			woke = true
		end)
		local started = os.clock()
		while not woke and os.clock() - started < left do
			task.wait(0.25)
		end
		connection:Disconnect()
		if woke then
			return false
		end
	end
	return true
end

local function loop()
	while true do
		-- Zapowiedź
		if nextAt - CONFIG.warnBefore > now() then
			if not waitUntil(nextAt - CONFIG.warnBefore) then
				continue
			end
			everyone("✨ Złota godzina za trzydzieści sekund! Przygotuj się do pracy.", "info")
		end
		if not waitUntil(nextAt) then
			continue
		end
		-- Start
		endsAt = nextAt + CONFIG.duration
		nextAt += CONFIG.interval
		publish()
		everyone("✨ ZŁOTA GODZINA! Wszystkie wypłaty i XP są podwójne przez trzy minuty!", "good")
		if not waitUntil(endsAt) then
			continue
		end
		endsAt = 0
		publish()
		everyone("Złota godzina się skończyła. Następna już niedługo!", "info")
	end
end

-- Komenda testowa: Złota godzina od razu
function GoldenHourService.StartNow()
	nextAt = now() + 1
	endsAt = 0
	publish()
	wakeUp:Fire()
end

function GoldenHourService.Init()
	nextAt = now() + CONFIG.firstAfter
	publish()
end

function GoldenHourService.Start()
	task.spawn(loop)
end

return GoldenHourService

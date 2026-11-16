-- Kody nagród (np. z YouTube, TikToka, grupy): gracz wpisuje kod w oknie prezentów, serwer sprawdza go
-- z listą w ServerScriptService.Config.RewardCodes. Każde konto użyje danego kodu tylko raz.
-- Po kilku błędnych próbach z rzędu jest krótka blokada (zgadywanie kodów nic nie da).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local RewardCodes = require(ServerScriptService.Config.RewardCodes)
local Rewards = require(ServerScriptService.Lib.Rewards)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)

local CodeService = {}

local byCode = {} -- [KOD] = wpis z RewardCodes
local attempts = {} -- [player] = { fails, blockedUntil }

local function normalize(text: string): string
	return string.upper((string.gsub(text, "%s", "")))
end

-- "RRRR-MM-DD" -> koniec tego dnia (czas serwera, UTC)
local function expiryOf(entry): number?
	if type(entry.expires) ~= "string" then
		return nil
	end
	local year, month, day = string.match(entry.expires, "^(%d+)-(%d+)-(%d+)$")
	if not year then
		return nil
	end
	return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 23, min = 59, sec = 59 })
end

local function fail(player: Player, message: string)
	local entry = attempts[player] or { fails = 0, blockedUntil = 0 }
	entry.fails += 1
	if entry.fails >= RewardsConfig.CODE_MAX_FAILS then
		entry.fails = 0
		entry.blockedUntil = os.clock() + RewardsConfig.CODE_COOLDOWN
	end
	attempts[player] = entry
	return { ok = false, message = message }
end

local function redeem(player: Player, text: any)
	local data = DataService.Get(player)
	if not data then
		return { ok = false, message = "Chwila, wczytuję dane..." }
	end
	local entry = attempts[player]
	if entry and os.clock() < entry.blockedUntil then
		return { ok = false, message = "Za dużo prób. Odczekaj chwilę i spróbuj znowu." }
	end
	if not RemoteService.IsString(text, RewardsConfig.CODE_MAX_LENGTH * 2) then
		return { ok = false, message = "Wpisz kod." }
	end
	local code = normalize(text)
	if code == "" or #code > RewardsConfig.CODE_MAX_LENGTH then
		return fail(player, "Nie ma takiego kodu. Sprawdź pisownię!")
	end
	local reward = byCode[code]
	if not reward then
		return fail(player, "Nie ma takiego kodu. Sprawdź pisownię!")
	end
	if data.codes[reward.id] then
		return { ok = false, message = "Ten kod został już użyty na tym koncie." }
	end
	local expires = expiryOf(reward)
	if expires and os.time() > expires then
		return { ok = false, message = "Ten kod już wygasł." }
	end
	data.codes[reward.id] = true
	attempts[player] = nil
	local labels = {}
	for _, prize in reward.rewards do
		local label = Rewards.Grant(player, prize, "code:" .. reward.id)
		if label then
			table.insert(labels, label)
		end
	end
	StateService.Push(player)
	-- Szerokie odstępy rozdzielają kawałki do tłumaczenia (Lang)
	return { ok = true, message = "Kod przyjęty!   " .. table.concat(labels, "   "), rewards = labels }
end

function CodeService.Init()
	for _, entry in RewardCodes do
		for _, code in entry.codes do
			local key = normalize(code)
			if byCode[key] then
				warn("[CodeService] Kod " .. key .. " jest wpisany dwa razy")
			end
			byCode[key] = entry
		end
	end
	RemoteService.OnServerInvoke(RemoteNames.Functions.RedeemCode, 1, redeem)
	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
	end)
end

-- Komenda testowa: wszystkie kody znowu do wpisania
function CodeService.DebugReset(player: Player)
	local data = DataService.Get(player)
	if data then
		data.codes = {}
	end
end

return CodeService

-- Wczytywanie i zapis danych graczy.
-- UpdateAsync + blokada sesji (dane nie dublują się przy przeskoku między serwerami),
-- ponawianie prób, autozapis, zapis przy wyjściu i przy zamknięciu serwera.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local DataService = {}

local IS_STUDIO = RunService:IsStudio()
local SERVER_ID = if IS_STUDIO then "studio" else game.JobId
local KEY_PREFIX = "Player_"
local MAX_ATTEMPTS = 3
local LOCK_RETRIES = 6
local LOCK_RETRY_DELAY = 5
local SHUTDOWN_TIMEOUT = 25

local TEMPLATE = {
	version = GameConfig.DATA_VERSION,
	coins = GameConfig.STARTING_COINS,
	upgrades = { flashlight = 1, shoes = 1, pockets = 1, stamina = 1 }, -- poziomy z ShopConfig
	settings = { jumpscares = true, sound = 1, lang = "auto" }, -- sound: 1 = wszystko, 2 = bez muzyki, 3 = cisza; lang: auto | pl | en
	stats = {
		rounds = 0,
		rentsPaid = 0,
		escapes = 0,
		caught = 0,
		coinsFound = 0,
		bestTime = 0, -- najszybsza zapłata czynszu (sekundy), 0 = jeszcze nigdy
	},
	tutorialDone = false,
	codes = {}, -- [id kodu] = true
	receipts = {}, -- zakupy za Robux (na przyszłość)
}

local store = nil
local profiles = {} -- [player] = { data, saveable, busy, leaving, released }
local loadedCallbacks = {}
local beforeReleaseCallbacks = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- Uzupełnia brakujące pola (np. po dodaniu nowych systemów)
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function migrate(data)
	-- Miejsce na przyszłe migracje, np.: if data.version < 2 then ... end
	data.version = GameConfig.DATA_VERSION
	return data
end

local function newData()
	return deepCopy(TEMPLATE)
end

local function prepare(raw)
	local data = if type(raw) == "table" then raw else newData()
	reconcile(data, TEMPLATE)
	return migrate(data)
end

local function withRetries(label: string, fn): boolean
	local delay = 1
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		warn(string.format("[DataService] %s: próba %d/%d nieudana: %s", label, attempt, MAX_ATTEMPTS, tostring(err)))
		if attempt < MAX_ATTEMPTS then
			task.wait(delay)
			delay *= 2
		end
	end
	return false
end

-- Zwraca "ok" + dane, "locked" albo "error"
local function tryLoad(userId: number)
	local status = "error"
	local loaded = nil
	local ok = withRetries("load " .. userId, function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(stored)
			stored = if type(stored) == "table" then stored else {}
			local lock = stored.lock
			local now = os.time()
			if lock and lock.owner ~= SERVER_ID and now - lock.time < GameConfig.SESSION_LOCK_STALE then
				status = "locked"
				return nil -- anuluj zapis, dane trzyma inny serwer
			end
			status = "ok"
			loaded = stored.data
			stored.lock = { owner = SERVER_ID, time = now }
			return stored
		end)
	end)
	if not ok then
		return "error", nil
	end
	return status, loaded
end

local function saveProfile(userId: number, profile, release: boolean): boolean
	if not profile.saveable or profile.released then
		return true
	end
	if not release and profile.leaving then
		return true
	end
	-- Jeden zapis naraz na gracza, żeby autozapis nie założył blokady po jej zwolnieniu
	while profile.busy do
		task.wait()
	end
	if profile.released then
		return true
	end
	profile.busy = true
	local lockLost = false
	local ok = withRetries("save " .. userId, function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(stored)
			stored = if type(stored) == "table" then stored else {}
			local lock = stored.lock
			if lock and lock.owner ~= SERVER_ID then
				lockLost = true
				return nil -- inny serwer przejął dane, nie nadpisujemy
			end
			lockLost = false
			stored.data = profile.data
			stored.lock = if release then nil else { owner = SERVER_ID, time = os.time() }
			return stored
		end)
	end)
	if lockLost then
		warn("[DataService] Blokada sesji gracza " .. userId .. " należy do innego serwera, zapis pominięty")
	end
	if ok and release then
		profile.released = true
	end
	profile.busy = false
	return ok and not lockLost
end

local function runBeforeRelease(player: Player, data)
	for _, callback in beforeReleaseCallbacks do
		local ok, err = pcall(callback, player, data)
		if not ok then
			warn("[DataService] Błąd przed zapisem: " .. tostring(err))
		end
	end
end

local function loadPlayer(player: Player)
	local userId = player.UserId
	local profile = nil
	local lastStatus = "error"

	if store then
		for attempt = 1, LOCK_RETRIES do
			local status, raw = tryLoad(userId)
			lastStatus = status
			if status == "ok" then
				profile = { data = prepare(raw), saveable = true, busy = false, leaving = false, released = false }
				break
			elseif status == "locked" then
				warn("[DataService] Dane gracza " .. userId .. " są zablokowane przez inny serwer, czekam...")
				if attempt < LOCK_RETRIES and player.Parent then
					task.wait(LOCK_RETRY_DELAY)
				end
			else
				break
			end
			if not player.Parent then
				break
			end
		end
	end

	-- Gracz wyszedł w trakcie wczytywania: od razu zwalniamy blokadę
	if not player.Parent then
		if profile then
			profile.leaving = true
			task.spawn(saveProfile, userId, profile, true)
		end
		return
	end

	if not profile then
		if IS_STUDIO then
			warn("[DataService] Brak dostępu do DataStore. Dane działają tylko w tej sesji. Włącz: Game Settings > Security > Enable Studio Access to API Services")
			profile = { data = newData(), saveable = false, busy = false, leaving = false, released = false }
		elseif lastStatus == "locked" then
			player:Kick("Twoje dane są jeszcze zapisywane na innym serwerze. Wejdź ponownie za minutę. / Your data is still saving on another server. Please rejoin in a minute.")
			return
		else
			player:Kick("Nie udało się wczytać Twoich danych. Spróbuj ponownie za chwilę. / Could not load your data. Please try again shortly.")
			return
		end
	end

	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	profile.leaving = true
	runBeforeRelease(player, profile.data)
	saveProfile(player.UserId, profile, true)
end

local function onShutdown()
	local pending = 0
	for player, profile in profiles do
		pending += 1
		profile.leaving = true
		task.spawn(function()
			runBeforeRelease(player, profile.data)
			saveProfile(player.UserId, profile, true)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < SHUTDOWN_TIMEOUT do
		task.wait(0.1)
	end
end

-- API dla innych serwisów --------------------------------------------------

-- Zwraca tabelę danych gracza albo nil, jeśli jeszcze się nie wczytały
function DataService.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.IsSaveable(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.saveable
end

-- callback(player, data) po wczytaniu danych (także dla graczy już obecnych)
function DataService.OnLoaded(callback)
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.data)
	end
end

-- callback(player, data) tuż przed ostatnim zapisem przy wyjściu gracza
function DataService.OnBeforeRelease(callback)
	table.insert(beforeReleaseCallbacks, callback)
end

function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return saveProfile(player.UserId, profile, false)
end

-- Tylko do testów w Studio
function DataService.ResetData(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	profile.data = newData()
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.data)
	end
	return true
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(if IS_STUDIO then GameConfig.DATASTORE_NAME_STUDIO else GameConfig.DATASTORE_NAME_LIVE)
	end)
	if ok then
		store = result
	else
		warn("[DataService] Nie można otworzyć DataStore: " .. tostring(result))
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	game:BindToClose(onShutdown)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(saveProfile, player.UserId, profile, false)
			end
		end
	end)
end

return DataService

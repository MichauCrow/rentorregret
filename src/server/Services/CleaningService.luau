-- Sprzątanie brudu przez ProximityPrompt. Wszystko sprawdza serwer:
-- uprawnienia, odległość, czas przytrzymania przycisku i tempo sprzątania.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)
local CosmeticsService = require(Services.CosmeticsService)

local CleaningService = {}

local holdStarts = {} -- [player] = { prompt, time }
local lastClean = {} -- [player] = os.clock()
local cleanedCallbacks = {}

local function getDirtPart(prompt: ProximityPrompt): BasePart?
	local parent = prompt.Parent
	if not parent or not parent:IsA("BasePart") or parent:GetAttribute("DirtId") == nil then
		return nil
	end
	local apartments = Workspace:FindFirstChild("Apartments")
	if not apartments or not parent:IsDescendantOf(apartments) then
		return nil
	end
	return parent
end

-- Mnożnik czasu przytrzymania ze sprzętu gracza (najlepszy przedmiot dla danego rodzaju brudu)
function CleaningService.GetHoldMultiplier(player: Player, kind: string): number
	local data = DataService.Get(player)
	local multiplier = 1
	if data then
		for itemId in data.equipment do
			local item = ShopConfig.Items[itemId]
			if item and item.holdMultiplier and item.holdMultiplier[kind] then
				multiplier = math.min(multiplier, item.holdMultiplier[kind])
			end
		end
	end
	return multiplier
end

-- Czas przytrzymania dla gracza (klient ustawia u siebie ten sam czas w podpowiedziach)
function CleaningService.GetHoldTime(player: Player, kind: string): number
	local definition = ApartmentConfig.Dirt[kind]
	local base = if definition then definition.holdTime else 1
	return base * CleaningService.GetHoldMultiplier(player, kind)
end

-- callback(owner, cleaner, rodzaj) po każdym sprzątnięciu w mieszkaniu
function CleaningService.OnCleaned(callback)
	table.insert(cleanedCallbacks, callback)
end

local function rewardHelper(helper: Player, owner: Player)
	local data = DataService.Get(helper)
	if not data then
		return
	end
	data.stats.helped += 1
	if data.monthly.helperCoins < ApartmentConfig.HELPER_COIN_CAP then
		data.monthly.helperCoins += ApartmentConfig.HELPER_COIN_PER_ITEM
		EconomyService.AddCoins(helper, ApartmentConfig.HELPER_COIN_PER_ITEM, "help:" .. owner.UserId)
	end
end

local function onHoldBegan(prompt: ProximityPrompt, player: Player)
	if getDirtPart(prompt) then
		holdStarts[player] = { prompt = prompt, time = os.clock() }
	end
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	local dirtPart = getDirtPart(prompt)
	if not dirtPart then
		return
	end
	local dirtId = dirtPart:GetAttribute("DirtId")
	local kind = dirtPart:GetAttribute("DirtKind")
	local owner = ApartmentService.GetOwnerOfInstance(dirtPart)
	if not owner or not ApartmentService.CanClean(owner, player) then
		return
	end

	-- Odległość
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - dirtPart.Position).Magnitude > ApartmentConfig.CLEAN_DISTANCE then
		return
	end

	-- Czas przytrzymania: musi być zarejestrowany początek na tej samej podpowiedzi
	local now = os.clock()
	local required = CleaningService.GetHoldTime(player, kind) * ApartmentConfig.HOLD_TOLERANCE
	local hold = holdStarts[player]
	holdStarts[player] = nil
	if required > 0 and (not hold or hold.prompt ~= prompt or now - hold.time < required) then
		return
	end

	-- Tempo
	if lastClean[player] and now - lastClean[player] < ApartmentConfig.MIN_CLEAN_INTERVAL then
		return
	end

	local position = dirtPart.Position
	-- RemoveDirt zwraca nil, jeśli brud już zniknął (np. dwa kliknięcia naraz), więc nie ma podwójnego liczenia
	local removedKind = ApartmentService.RemoveDirt(owner, dirtId)
	if not removedKind then
		return
	end
	lastClean[player] = now

	local data = DataService.Get(player)
	if data then
		data.stats.cleaned += 1
	end
	if player ~= owner then
		rewardHelper(player, owner)
	end
	for _, callback in cleanedCallbacks do
		task.spawn(callback, owner, player, removedKind)
	end

	local points = ApartmentConfig.Dirt[removedKind].penalty
	RemoteService.Event(RemoteNames.Events.CleanFx):FireAllClients(position, removedKind, points, CosmeticsService.GetSparkleColor(player))

	if ApartmentService.GetDirtCount(owner) == 0 then
		StateService.Notify(owner, "Mieszkanie lśni! Wszystko posprzątane", "good")
		RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(owner, position, "allClean", 0)
	end
end

function CleaningService.Init()
	-- Klient potrzebuje mnożników, żeby pokazać krótsze przytrzymanie w podpowiedziach
	StateService.AddProvider(function(player, snapshot)
		local multipliers = {}
		for kind in ApartmentConfig.Dirt do
			local multiplier = CleaningService.GetHoldMultiplier(player, kind)
			if multiplier < 1 then
				multipliers[kind] = multiplier
			end
		end
		snapshot.holdMultipliers = multipliers
	end)
end

function CleaningService.Start()
	ProximityPromptService.PromptButtonHoldBegan:Connect(onHoldBegan)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	Players.PlayerRemoving:Connect(function(player)
		holdStarts[player] = nil
		lastClean[player] = nil
	end)
end

return CleaningService

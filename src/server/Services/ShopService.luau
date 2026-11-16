-- Sklep "Mebelkowo": katalog, zakupy (sprawdzane na serwerze) i robot sprzątający.
-- Ceny uwzględniają wyprzedaż z EventService. Meble trafiają na wolne miejsca w mieszkaniu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)
local EventService = require(Services.EventService)
local CosmeticsService = require(Services.CosmeticsService)

local ShopService = {}

local ROBOT_KINDS = { "trash", "stain", "dishes" }

local robotTimers = {} -- [player] = sekundy

local function priceFor(player: Player, item): number
	local discount = EventService.GetShopDiscount(player)
	return math.max(1, math.floor(item.price * (1 - discount) + 0.5))
end

local function furnitureCount(data, itemId: string): number
	local count = 0
	for _, owned in data.apartment.furniture do
		if type(owned) == "table" and owned.id == itemId then
			count += 1
		end
	end
	return count
end

function ShopService.BuildCatalog(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local items = {}
	for _, itemId in ShopConfig.Order do
		local item = ShopConfig.Items[itemId]
		local isFurniture = item.category == "furniture"
		table.insert(items, {
			id = itemId,
			category = item.category,
			name = item.name,
			emoji = item.emoji,
			description = if isFurniture then string.format("+%d komfortu", item.comfort) else item.description,
			price = priceFor(player, item),
			basePrice = item.price,
			unlocked = data.highestMonth >= item.unlockMonth,
			unlockMonth = item.unlockMonth,
			owned = not isFurniture and data.equipment[itemId] == true,
			ownedCount = if isFurniture then furnitureCount(data, itemId) else 0,
			spot = item.spot,
		})
	end
	return {
		coins = data.coins,
		discount = EventService.GetShopDiscount(player),
		freeSpots = {
			floor = ApartmentService.FreeSpots(player, "floor"),
			rug = ApartmentService.FreeSpots(player, "rug"),
		},
		items = items,
		cosmetics = CosmeticsService.BuildList(player),
	}
end

-- Zwraca (sukces, komunikat)
local function buy(player: Player, itemId: any): (boolean, string)
	if not RemoteService.IsString(itemId, 32) or not ShopConfig.Items[itemId] then
		return false, "Nieznany przedmiot."
	end
	local item = ShopConfig.Items[itemId]
	local data = DataService.Get(player)
	if not data then
		return false, "Chwila, wczytuję dane..."
	end
	if data.highestMonth < item.unlockMonth then
		return false, string.format("Dostępne od miesiąca %d.", item.unlockMonth)
	end
	if item.category == "furniture" then
		if ApartmentService.FreeSpots(player, item.spot) <= 0 then
			return false, "Brak miejsca w mieszkaniu na ten mebel."
		end
	elseif data.equipment[itemId] then
		return false, "Już to masz!"
	end
	local price = priceFor(player, item)
	if not EconomyService.TrySpend(player, price, "shop:" .. itemId) then
		return false, "Za mało monet."
	end
	if item.category == "furniture" then
		table.insert(data.apartment.furniture, { id = itemId, name = item.name })
		ApartmentService.RenderFurniture(player)
		-- Gracz sam wybiera miejsce (póki nie wybierze, mebel stoi na miejscu automatycznym)
		ApartmentService.StartPlacement(player, #data.apartment.furniture)
	else
		data.equipment[itemId] = true
	end
	ApartmentService.Recalculate(player)
	StateService.Push(player)
	return true, string.format("Kupiono: %s %s!", item.emoji, item.name)
end

local function tickRobots()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data and data.equipment.robot then
			robotTimers[player] = (robotTimers[player] or 0) + 1
			if robotTimers[player] >= ShopConfig.Items.robot.robotInterval then
				robotTimers[player] = 0
				local kind, position = ApartmentService.RemoveOneDirt(player, ROBOT_KINDS)
				if kind and position then
					RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, position, kind, 0)
				end
			end
		end
	end
end

function ShopService.Init()
	RemoteService.OnServerInvoke(RemoteNames.Functions.GetShop, 3, function(player)
		return ShopService.BuildCatalog(player)
	end)
	RemoteService.OnServerInvoke(RemoteNames.Functions.BuyItem, 3, function(player, itemId)
		local ok, message = buy(player, itemId)
		if ok then
			StateService.Notify(player, message, "good")
		end
		return { ok = ok, message = message, catalog = ShopService.BuildCatalog(player) }
	end)
end

function ShopService.Start()
	Players.PlayerRemoving:Connect(function(player)
		robotTimers[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tickRobots()
		end
	end)
end

return ShopService

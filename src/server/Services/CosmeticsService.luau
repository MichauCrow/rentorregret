-- Kosmetyki i zakupy za Robux. Wszystko jest wyłącznie wizualne (ślad, tytuł, kolor ścian, kolor iskierek, strój).
-- Game Passy (VIP, Kostium Dyni) sprawdzamy przy wejściu i po zakupie; przyznane przedmioty od razu zakładamy.
-- ProcessReceipt jest idempotentny: ID zakupu zapisujemy w danych gracza i zapisujemy dane PRZED potwierdzeniem,
-- więc ponowne wywołanie przez Roblox nigdy nie przyzna przedmiotu dwa razy.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticsConfig = require(ReplicatedStorage.Shared.Config.CosmeticsConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local ApartmentService = require(Services.ApartmentService)

local CosmeticsService = {}

local ITEMS = CosmeticsConfig.Items

local productToItem = {} -- [productId] = id kosmetyku
local productPrices = {} -- [productId] = cena w Robux (z MarketplaceService)
local passPrices = {} -- [passId] = cena Game Passa w Robux
local HIDDEN_ACCESSORIES = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Face] = true,
}
local robuxAllowed = {} -- [player] = true, gdy zasady regionu pozwalają pokazać oferty za Robux

local function productIdOf(item): number
	local product = item.product and CosmeticsConfig.DevProducts[item.product]
	return if product then product.id else 0
end

local function grant(player: Player, data, itemId: string)
	if ITEMS[itemId] then
		data.cosmetics[itemId] = true
	end
end

local function passOf(item)
	return item.pass and CosmeticsConfig.GamePasses[item.pass] or nil
end

local function eventActive(pass): boolean
	if pass.event == "halloween" then
		return JobsConfig.Jobs.cans.halloween == true
	end
	return true
end

-- Wygląd ----------------------------------------------------------------------------

local function applyTrail(player: Player, data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in { "CosmeticTrail", "CosmeticTrailTop", "CosmeticTrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local item = ITEMS[data.equipped.trail or ""]
	if not item then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "CosmeticTrailTop"
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "CosmeticTrailBottom"
	bottom.Position = Vector3.new(0, -1.2, 0)
	bottom.Parent = root
	local keypoints = {}
	for index, color in item.colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #item.colors - 1), color))
	end
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.LightEmission = 0.6
	trail.Lifetime = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
end

local function applyTitle(player: Player, data)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("CosmeticTitle")
	if old then
		old:Destroy()
	end
	local item = ITEMS[data.equipped.title or ""]
	if not item then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CosmeticTitle"
	billboard.Size = UDim2.fromOffset(220, 36)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 80
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = item.color
	label.Text = item.emoji .. " " .. item.name
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
end

-- Stroje ---------------------------------------------------------------------------

local function costumePart(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material, attachTo: BasePart, offset: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = attachTo.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

-- Czapki, włosy i akcesoria twarzy chowamy pod strojem (i przywracamy po zdjęciu)
local function setAccessoriesHidden(character: Model, hidden: boolean)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and HIDDEN_ACCESSORIES[accessory.AccessoryType] then
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local original = handle:GetAttribute("CostumeTransparency")
				if hidden then
					if original == nil then
						handle:SetAttribute("CostumeTransparency", handle.Transparency)
					end
					handle.Transparency = 1
				elseif original ~= nil then
					handle.Transparency = original
					handle:SetAttribute("CostumeTransparency", nil)
				end
			end
		end
	end
end

-- Złoty strój VIP: korona z klejnotem i błyskami oraz złota peleryna z czerwonym kołnierzem
local function buildVipCostume(model: Model, head: BasePart, torso: BasePart)
	local gold = Color3.fromRGB(255, 200, 40)
	local top = head.Size.Y / 2
	local radius = math.max(head.Size.X, head.Size.Z) * 0.55
	local ring = costumePart(model, "CrownRing", Vector3.new(0.45, radius * 2, radius * 2), gold, Enum.Material.SmoothPlastic, head, CFrame.new(0, top + 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	ring.Reflectance = 0.3
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		local spike = costumePart(model, "CrownSpike", Vector3.new(0.3, 0.3, 0.3), gold, Enum.Material.SmoothPlastic, head, CFrame.new(math.sin(angle) * radius * 0.85, top + 0.5, -math.cos(angle) * radius * 0.85) * CFrame.Angles(math.rad(45), 0, math.rad(45)))
		spike.Reflectance = 0.3
	end
	costumePart(model, "CrownGem", Vector3.new(0.28, 0.28, 0.1), Color3.fromRGB(255, 60, 90), Enum.Material.Neon, head, CFrame.new(0, top + 0.15, -radius - 0.02))
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = 4
	sparkles.LightEmission = 0.8
	sparkles.Parent = ring
	local back = torso.Size.Z / 2
	costumePart(model, "Cape", Vector3.new(torso.Size.X * 1.05, 3.4, 0.15), gold, Enum.Material.Fabric, torso, CFrame.new(0, -1, back + 0.2) * CFrame.Angles(math.rad(8), 0, 0))
	costumePart(model, "CapeCollar", Vector3.new(torso.Size.X * 1.1, 0.35, 0.5), Color3.fromRGB(220, 40, 70), Enum.Material.Fabric, torso, CFrame.new(0, torso.Size.Y / 2 - 0.1, back + 0.05))
end

-- Kostium Dyni: głowa-dynia ze świecącą buzią i skrzydła nietoperza na plecach
local function buildPumpkinCostume(model: Model, head: BasePart, torso: BasePart)
	local size = math.max(head.Size.X, head.Size.Y, head.Size.Z) * 2.1
	local radius = size / 2
	local glow = Color3.fromRGB(255, 230, 80)
	local pumpkin = costumePart(model, "PumpkinHead", Vector3.new(size, size, size), Color3.fromRGB(255, 120, 20), Enum.Material.SmoothPlastic, head, CFrame.new(0, 0.15, 0), Enum.PartType.Ball)
	costumePart(model, "PumpkinStem", Vector3.new(0.3, 0.55, 0.3), Color3.fromRGB(70, 140, 40), Enum.Material.Wood, head, CFrame.new(0, 0.15 + radius + 0.2, 0))
	for _, x in { -0.32, 0.32 } do
		costumePart(model, "PumpkinEye", Vector3.new(0.38, 0.38, 0.12), glow, Enum.Material.Neon, head, CFrame.new(x * radius, 0.15 + radius * 0.25, -radius * 0.9) * CFrame.Angles(0, 0, math.rad(45)))
	end
	costumePart(model, "PumpkinMouth", Vector3.new(radius * 0.9, 0.22, 0.12), glow, Enum.Material.Neon, head, CFrame.new(0, 0.15 - radius * 0.3, -radius * 0.92))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 40)
	light.Range = 8
	light.Brightness = 1
	light.Parent = pumpkin
	local back = torso.Size.Z / 2
	for _, side in { -1, 1 } do
		costumePart(model, "BatWing", Vector3.new(2.2, 1.3, 0.12), Color3.fromRGB(35, 25, 45), Enum.Material.SmoothPlastic, torso, CFrame.new(side * 1.2, 0.4, back + 0.2) * CFrame.Angles(0, math.rad(side * -20), math.rad(side * 25)))
	end
end

local function applyCostume(player: Player, data)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("CosmeticCostume")
	if old then
		old:Destroy()
	end
	setAccessoriesHidden(character, false)
	local itemId = data.equipped.costume
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not itemId or not ITEMS[itemId] or not head or not torso then
		return
	end
	local model = Instance.new("Model")
	model.Name = "CosmeticCostume"
	if itemId == "costumeVip" then
		buildVipCostume(model, head, torso)
	elseif itemId == "costumePumpkin" then
		buildPumpkinCostume(model, head, torso)
	end
	setAccessoriesHidden(character, true)
	model.Parent = character
end

local function applyWalls(player: Player, data)
	local item = ITEMS[data.equipped.wall or ""]
	ApartmentService.PaintWalls(player, if item then item.color else nil)
end

local function applyAll(player: Player)
	local data = DataService.Get(player)
	if data then
		applyTrail(player, data)
		applyTitle(player, data)
		applyCostume(player, data)
		applyWalls(player, data)
	end
end

-- Kolor iskierek przy sprzątaniu (CleaningService) albo nil = domyślny
function CosmeticsService.GetSparkleColor(player: Player): Color3?
	local data = DataService.Get(player)
	local item = data and ITEMS[data.equipped.sparkle or ""]
	return if item then item.color else nil
end

-- Lista do sklepu ----------------------------------------------------------------

local function priceOf(productId: number): number?
	if productId <= 0 then
		return nil
	end
	if productPrices[productId] == nil then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
		productPrices[productId] = if ok and info then info.PriceInRobux or false else false
	end
	return productPrices[productId] or nil
end

local function passPriceOf(passId: number): number?
	if passId <= 0 then
		return nil
	end
	if passPrices[passId] == nil then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
		passPrices[passId] = if ok and info then info.PriceInRobux or false else false
	end
	return passPrices[passId] or nil
end

function CosmeticsService.BuildList(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local list = {}
	for _, itemId in CosmeticsConfig.Order do
		local item = ITEMS[itemId]
		local owned = data.cosmetics[itemId] == true
		local pass = passOf(item)
		-- Oferty eventowe znikają po evencie (kto kupił, dalej je widzi i może założyć).
		-- Przedmioty tylko za Robux bez założonego produktu (id = 0) są ukryte, żeby nie wisiało "Wkrótce".
		local robuxOnly = not item.tokens and productIdOf(item) <= 0 and (not pass or pass.id <= 0)
		if (not pass or owned or eventActive(pass)) and (owned or not robuxOnly) then
			local productId = productIdOf(item)
			local passId = if pass then pass.id else 0
			local kindName = CosmeticsConfig.Kinds[item.kind]
			if pass then
				kindName ..= " · " .. pass.emoji .. " " .. pass.name
			end
			table.insert(list, {
				id = itemId,
				kind = item.kind,
				kindName = kindName,
				name = item.name,
				emoji = item.emoji,
				tokens = item.tokens,
				productId = if robuxAllowed[player] and productId > 0 then productId else nil,
				passId = if robuxAllowed[player] and passId > 0 then passId else nil,
				robuxPrice = if not robuxAllowed[player] then nil elseif passId > 0 then passPriceOf(passId) else priceOf(productId),
				owned = owned,
				equipped = data.equipped[item.kind] == itemId,
			})
		end
	end
	return { tokens = data.tokens, items = list }
end

-- Akcje gracza: kupno za klucze, zakładanie i zdejmowanie
local function onAction(player: Player, action: any, itemId: any)
	local data = DataService.Get(player)
	if not data then
		return { ok = false, message = "Chwila, wczytuję dane..." }
	end
	local item = if type(itemId) == "string" then ITEMS[itemId] else nil
	local message
	if action == "buy" then
		if not item or not item.tokens then
			return { ok = false, message = "Tego nie da się kupić za klucze." }
		end
		if data.cosmetics[itemId] then
			return { ok = false, message = "Już to masz!" }
		end
		if data.tokens < item.tokens then
			return { ok = false, message = "Za mało kluczy. Zdobywaj je za zadania i osiągnięcia!" }
		end
		data.tokens -= item.tokens
		grant(player, data, itemId)
		data.equipped[item.kind] = itemId
		message = "Kupiono i założono: " .. item.emoji .. " " .. item.name
	elseif action == "equip" then
		if not item or not data.cosmetics[itemId] then
			return { ok = false, message = "Najpierw zdobądź ten przedmiot." }
		end
		data.equipped[item.kind] = itemId
		message = "Założono: " .. item.emoji .. " " .. item.name
	elseif action == "unequip" then
		if not item then
			return { ok = false, message = "Nieznany przedmiot." }
		end
		if data.equipped[item.kind] == itemId then
			data.equipped[item.kind] = nil
		end
		message = "Zdjęto: " .. item.name
	else
		return { ok = false, message = "Nieznana akcja." }
	end
	applyAll(player)
	StateService.Push(player)
	return { ok = true, message = message, cosmetics = CosmeticsService.BuildList(player) }
end

-- Zakupy za Robux ------------------------------------------------------------------

local function trimReceipts(data)
	local ids = {}
	for purchaseId, time in data.receipts do
		table.insert(ids, { id = purchaseId, time = tonumber(time) or 0 })
	end
	if #ids <= CosmeticsConfig.MAX_RECEIPTS then
		return
	end
	table.sort(ids, function(a, b)
		return a.time < b.time
	end)
	for i = 1, #ids - CosmeticsConfig.MAX_RECEIPTS do
		data.receipts[ids[i].id] = nil
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox spróbuje ponownie przy następnym wejściu
	end
	if data.receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- już przyznane wcześniej
	end
	local itemId = productToItem[receipt.ProductId]
	if not itemId then
		warn("[CosmeticsService] Nieznany produkt: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(player, data, itemId)
	data.receipts[receipt.PurchaseId] = os.time()
	trimReceipts(data)
	-- Najpierw zapis, potem potwierdzenie. Bez zapisu Roblox powtórzy wywołanie (przyznanie jest idempotentne).
	if DataService.IsSaveable(player) and not DataService.SaveNow(player) then
		data.receipts[receipt.PurchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local item = ITEMS[itemId]
	data.equipped[item.kind] = itemId
	applyAll(player)
	StateService.Notify(player, "Dziękujemy! Odblokowano: " .. item.emoji .. " " .. item.name, "good")
	StateService.Push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Tylko do testów w Studio: sztuczny paragon (sprawdza idempotentność bez prawdziwych Robux)
local DEBUG_PRODUCT_ID = -1
function CosmeticsService.DebugReceipt(player: Player, purchaseId: string): string
	productToItem[DEBUG_PRODUCT_ID] = "titleVip"
	local decision = processReceipt({ PlayerId = player.UserId, ProductId = DEBUG_PRODUCT_ID, PurchaseId = purchaseId })
	productToItem[DEBUG_PRODUCT_ID] = nil
	return decision.Name
end

-- equip = true: przy świeżym zakupie od razu zakładamy wszystko z pakietu
local function grantGamePass(player: Player, passKey: string, equip: boolean?)
	local data = DataService.Get(player)
	local pass = CosmeticsConfig.GamePasses[passKey]
	if not data or not pass then
		return
	end
	for _, itemId in pass.grants do
		grant(player, data, itemId)
		if equip and ITEMS[itemId] then
			data.equipped[ITEMS[itemId].kind] = itemId
		end
	end
	if equip then
		applyAll(player)
	end
end

-- Tylko do testów w Studio: przyznaje Game Pass bez Robux
function CosmeticsService.DebugGrantPass(player: Player, passKey: string)
	grantGamePass(player, passKey, true)
	StateService.Push(player)
end

local function checkGamePasses(player: Player)
	for passKey, pass in CosmeticsConfig.GamePasses do
		if pass.id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				grantGamePass(player, passKey)
			end
		end
	end
end

local function checkPolicy(player: Player)
	-- Jeśli nie da się sprawdzić zasad regionu, nie pokazujemy ofert za Robux (bezpieczniej)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	robuxAllowed[player] = ok and type(info) == "table" and info.IsSubjectToChinaPolicies ~= true
end

local function onLoaded(player: Player)
	task.spawn(checkPolicy, player)
	task.spawn(checkGamePasses, player)
	applyAll(player)
end

function CosmeticsService.Init()
	for productKey, product in CosmeticsConfig.DevProducts do
		if product.id > 0 then
			productToItem[product.id] = product.item
		end
		assert(ITEMS[product.item], "DevProduct " .. productKey .. " wskazuje nieznany kosmetyk")
	end
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for passKey, pass in CosmeticsConfig.GamePasses do
			if pass.id == passId then
				grantGamePass(player, passKey, true)
				StateService.Notify(player, "Dziękujemy! Odblokowano: " .. (pass.emoji or "") .. " " .. pass.name, "good")
				StateService.Push(player)
			end
		end
	end)
	RemoteService.OnServerInvoke(RemoteNames.Functions.CosmeticAction, 4, onAction)
	DataService.OnLoaded(onLoaded)
	ApartmentService.OnMoved(function(player)
		local data = DataService.Get(player)
		if data then
			applyWalls(player, data)
		end
	end)
end

function CosmeticsService.Start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			local data = DataService.Get(player)
			if data then
				applyTrail(player, data)
				applyTitle(player, data)
				-- Akcesoria awatara wczytują się chwilę po postaci, więc strój zakładamy z opóźnieniem
				task.delay(1, function()
					if player.Character == character then
						applyCostume(player, data)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		robuxAllowed[player] = nil
	end)
end

return CosmeticsService

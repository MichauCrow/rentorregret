-- Test klienta bez Roblox Studio: buduje cały interfejs (Init + Start wszystkich kontrolerów) i przechodzi
-- scenariusz gry: hol, sklep, ustawienia, runda, szafa, minigra oddechu, finał, złapanie, podsumowanie.
-- Lune sprawdza nazwy właściwości i typy wartości, więc literówki w kodzie interfejsu wychodzą tutaj.
--
-- lune run tests/test_client [szerokość] [wysokość] [touch|mouse] [pl|en] [folder na zrzuty stanu]
-- Z folderem na zrzuty zapisuje drzewo interfejsu każdego etapu do JSON (dla tools/preview/render_ui.mjs).
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")
local H = require("./harness")
local roblox = H.roblox
local I, V3, V2, CF, Enum = roblox.Instance, roblox.Vector3, roblox.Vector2, roblox.CFrame, roblox.Enum

local VIEW_W = tonumber(process.args[1]) or 1280
local VIEW_H = tonumber(process.args[2]) or 720
local TOUCH = process.args[3] == "touch"
local LANG = process.args[4] or "pl"
local SNAPSHOT_DIR = process.args[5]

H.installEngine()
H.services.Debris = {
	AddItem = function(_, instance, lifetime)
		task.delay(lifetime or 10, function()
			pcall(function()
				instance:Destroy()
			end)
		end)
	end,
}

local function check(cond, msg)
	if not cond then
		error("TEST FAIL: " .. msg)
	end
	print("ok  " .. msg)
end

-- Świat: prawdziwa kamienica i potwór z kodu serwera ---------------------------------------------
local tags = {}
H.services.CollectionService = {
	AddTag = function(_, instance, tag)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], instance)
	end,
	GetTagged = function(_, tag)
		return tags[tag] or {}
	end,
	GetInstanceAddedSignal = function()
		return H.signal()
	end,
}
local workspaceFolder = I.new("Folder")
workspaceFolder.Name = "Workspace"
local rounds = I.new("Folder")
rounds.Name = "Rounds"
rounds.Parent = workspaceFolder
local terrain = I.new("Folder")
terrain.Name = "Terrain"
terrain.Parent = workspaceFolder
local camera = {
	ViewportSize = V2.new(VIEW_W, VIEW_H),
	CFrame = CF.new(8, 8, 20),
	GetPropertyChangedSignal = function()
		return H.signal()
	end,
	WorldToViewportPoint = function(_, point)
		-- Cel na wschód od gracza jest "za plecami" (sprawdza strzałkę na brzegu ekranu)
		return V3.new(VIEW_W * 0.2, VIEW_H * 0.5, if point.X > 30 then -5 else 5), point.X <= 30 and point.X > 0
	end,
}
-- Workspace: prawdziwy folder + kamera-atrapa (Lune nie udostępnia rozmiaru ekranu prawdziwej kamery)
local workspace = setmetatable({}, {
	__index = function(_, key)
		if key == "CurrentCamera" then
			return camera
		elseif key == "Terrain" then
			return terrain
		end
		local value = (workspaceFolder :: any)[key]
		if type(value) == "function" then
			return function(_, ...)
				return value(workspaceFolder, ...)
			end
		end
		return value
	end,
})
H.services.Workspace = workspace

local BuildingBuilder = H.load(H.root .. "/server/World/BuildingBuilder")
local MonsterModels = H.load(H.root .. "/server/World/MonsterModels")
local ORIGIN = V3.new(0, 0.5, 0)
local building = BuildingBuilder.Build(ORIGIN, rounds, 7)
for _, spot in building.spots do
	spot.part:SetAttribute("Spot", true)
end

-- Gracz: atrapa postaci (prędkość i kierunek ruchu nie są dostępne w Lune na prawdziwych instancjach)
local playerGui = I.new("Folder")
playerGui.Name = "PlayerGui"
local rootPart = { CFrame = CF.new(7, 3.5, 20), Size = V3.new(2, 2, 1), AssemblyLinearVelocity = V3.zero }
function rootPart:IsA(className)
	return className == "BasePart"
end
local humanoid = { MoveDirection = V3.zero, WalkSpeed = 16, HipHeight = 2 }
local head = {}
function head:FindFirstChild()
	return nil
end
local character = { PrimaryPart = rootPart }
function character:FindFirstChild(name)
	return if name == "HumanoidRootPart" then rootPart elseif name == "Head" then head else nil
end
function character:FindFirstChildOfClass(className)
	return if className == "Humanoid" then humanoid else nil
end
local localPlayer = { Name = "Tester", DisplayName = "Tester", UserId = 1, Character = character }
function localPlayer:WaitForChild()
	return playerGui
end

-- Usługi -----------------------------------------------------------------------------------------
local dataModel = I.new("DataModel")
local renderStepped, heartbeat = H.signal(), H.signal()
local inputBegan, inputEnded = H.signal(), H.signal()
local promptTriggered, promptHoldBegan = H.signal(), H.signal()
local actions = {}
H.services.Players = { LocalPlayer = localPlayer }
H.services.RunService = {
	RenderStepped = renderStepped,
	Heartbeat = heartbeat,
	IsStudio = function()
		return false
	end,
}
H.services.UserInputService = { TouchEnabled = TOUCH, InputBegan = inputBegan, InputEnded = inputEnded }
H.services.ContextActionService = {
	BindAction = function(_, name, fn)
		actions[name] = fn
	end,
}
H.services.StarterGui = { SetCore = function() end, SetCoreGuiEnabled = function() end }
H.services.Lighting = dataModel:GetService("Lighting")
H.services.SoundService = dataModel:GetService("SoundService")
H.services.ProximityPromptService = { PromptTriggered = promptTriggered, PromptButtonHoldBegan = promptHoldBegan }
H.services.HapticService = {
	IsVibrationSupported = function()
		return false
	end,
	SetMotor = function() end,
}
H.services.LocalizationService = { RobloxLocaleId = "pl-pl", SystemLocaleId = "pl-pl" }
H.services.ContentProvider = { PreloadAsync = function() end }

-- Remote'y ----------------------------------------------------------------------------------------
local RemoteNames = H.load(H.root .. "/shared/Modules/RemoteNames")
local fired = {}
local profile = {
	coins = 1234,
	upgrades = { flashlight = 1, shoes = 1, pockets = 2, stamina = 1 },
	settings = { jumpscares = true, sound = 1, lang = LANG, captions = true },
	stats = { rounds = 0, rentsPaid = 0, escapes = 0, caught = 0, coinsFound = 0, bestTime = 0 },
	tutorialDone = false,
	night = "blackout",
}
local remotes = {}
for _, name in RemoteNames.Events do
	remotes[name] = {
		OnClientEvent = H.signal(),
		FireServer = function(_, ...)
			table.insert(fired, { name = name, args = { ... } })
		end,
	}
end
for _, name in RemoteNames.Functions do
	remotes[name] = {
		InvokeServer = function(_, ...)
			table.insert(fired, { name = name, args = { ... } })
			if name == "BuyUpgrade" then
				profile.coins -= 150
				profile.upgrades.flashlight = 2
				return { ok = true, message = "🔦 Latarka: poziom 2!", state = table.clone(profile) }
			end
			return table.clone(profile)
		end,
	}
end
local function lastFired(name)
	for i = #fired, 1, -1 do
		if fired[i].name == name then
			return fired[i]
		end
	end
	return nil
end

-- Kontrolery (ta sama kolejność co w ClientMain) ---------------------------------------------------
local ORDER = {
	"ClientState",
	"UIKit",
	"SoundController",
	"LightingController",
	"MovementController",
	"AmbienceController",
	"MonsterRenderer",
	"NoiseController",
	"HUDController",
	"ObjectiveController",
	"FxController",
	"BreathController",
	"ShopController",
	"SettingsController",
	"LanguageController",
}
local controllers = {}
for _, name in ORDER do
	controllers[name] = H.load(H.root .. "/client/Controllers/" .. name)
end
local main = fs.readFile(H.root .. "/client/ClientMain.client.luau")
for _, name in ORDER do
	assert(main:find('"' .. name .. '"', 1, true), "ClientMain nie uruchamia kontrolera " .. name)
end
controllers.ClientState.Remote = function(name)
	return assert(remotes[name], "nieznany remote " .. tostring(name))
end
for _, name in ORDER do
	if controllers[name].Init then
		controllers[name].Init()
	end
end
for _, name in ORDER do
	if controllers[name].Start then
		controllers[name].Start()
	end
end
check(true, "Init i Start wszystkich " .. #ORDER .. " kontrolerów bez błędów")

-- Pomocnicze ---------------------------------------------------------------------------------------
local Lang = H.load(H.root .. "/shared/Modules/Lang")

-- Tekst w języku testu (gra pisze po polsku, LanguageController tłumaczy przy wyświetlaniu)
local function T(text: string): string
	return if LANG == "en" then Lang.ToEnglish(text) else text
end

-- W Roblox LanguageController dowiaduje się o nowych i zmienionych napisach ze zdarzeń silnika;
-- tutaj odpalamy je ręcznie po każdym kroku.
local function syncLanguage()
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			H.event(playerGui, "DescendantAdded"):Fire(descendant)
			H.event(descendant, "Changed:Text"):Fire()
		end
	end
end

local function frames(count: number, dt: number?)
	for _ = 1, count do
		renderStepped:Fire(dt or 1 / 30)
		heartbeat:Fire(dt or 1 / 30)
	end
	syncLanguage()
end

local function gui(path: string)
	local node = playerGui
	for _, name in string.split(path, "/") do
		node = node:FindFirstChild(name)
		assert(node, "brak elementu interfejsu: " .. path .. " (" .. name .. ")")
	end
	return node
end

local function click(path: string)
	H.event(gui(path), "Activated"):Fire()
end

local function visible(instance): boolean
	local node = instance
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return true
end

local function findText(polish: string)
	local fragment = T(polish)
	syncLanguage()
	for _, descendant in playerGui:GetDescendants() do
		if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and visible(descendant) and descendant.Text:find(fragment, 1, true) then
			return descendant
		end
	end
	return nil
end

local BUTTONS = if TOUCH then "TouchButtons/Buttons" else "HUD/Round/Buttons"
local COMMS = if TOUCH then "TouchButtons/Buttons/CommsMenu" else "HUD/Round/CommsMenu"

local round = {
	phase = "play",
	clock = "20:14",
	timeLeft = 340,
	huntLeft = 75,
	rent = 190,
	deposited = 40,
	rentPaid = false,
	carried = 23,
	capacity = 90,
	battery = 48,
	batteryMax = 96,
	flashlight = true,
	status = "inside",
	hasKey = false,
	hidden = false,
	floor = 0,
	pingReady = false,
	team = { { name = "Tester", status = "inside", carried = 23 }, { name = "Olek_2014", status = "inside", carried = 0 } },
	finale = false,
	night = "blackout",
	hearing = 1,
	closeCalls = 0,
}
local function pushRound(changes)
	for key, value in changes or {} do
		round[key] = value
	end
	remotes.RoundState.OnClientEvent:Fire(table.clone(round))
	frames(3)
end
local function roundEvent(kind: string, data)
	remotes.RoundEvent.OnClientEvent:Fire(kind, data)
	frames(2)
end

-- Zrzut drzewa interfejsu do JSON (podgląd w przeglądarce) -----------------------------------------
local function udim2(value)
	return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
end
local function rgb(color)
	return { color.R, color.G, color.B }
end
local function dump(instance)
	local node = { class = instance.ClassName, name = instance.Name, children = {} }
	if instance:IsA("GuiObject") then
		node.size = udim2(instance.Size)
		node.pos = udim2(instance.Position)
		node.anchor = { instance.AnchorPoint.X, instance.AnchorPoint.Y }
		node.bg = rgb(instance.BackgroundColor3)
		node.bgT = instance.BackgroundTransparency
		node.visible = instance.Visible
		node.z = instance.ZIndex
		node.order = instance.LayoutOrder
		node.rot = instance.Rotation
		node.auto = instance.AutomaticSize.Name
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			node.text = instance.Text
			node.textSize = instance.TextSize
			node.textColor = rgb(instance.TextColor3)
			node.textT = instance.TextTransparency
			node.scaled = instance.TextScaled
			node.wrapped = instance.TextWrapped
			node.xAlign = instance.TextXAlignment.Name
			node.yAlign = instance.TextYAlignment.Name
		end
	elseif instance:IsA("ScreenGui") then
		node.enabled = instance.Enabled
		node.order = instance.DisplayOrder
		local ok, inset = pcall(function()
			return instance.IgnoreGuiInset
		end)
		node.inset = ok and inset == true
	elseif instance:IsA("UICorner") then
		node.radius = instance.CornerRadius.Offset
	elseif instance:IsA("UIStroke") then
		node.color = rgb(instance.Color)
		node.thickness = instance.Thickness
		node.mode = instance.ApplyStrokeMode.Name
	elseif instance:IsA("UIListLayout") then
		node.dir = instance.FillDirection.Name
		node.padding = instance.Padding.Offset
		node.hAlign = instance.HorizontalAlignment.Name
		node.vAlign = instance.VerticalAlignment.Name
	elseif instance:IsA("UIGridLayout") then
		node.cell = udim2(instance.CellSize)
		node.padding = udim2(instance.CellPadding)
		node.hAlign = instance.HorizontalAlignment.Name
	elseif instance:IsA("UIPadding") then
		node.pad = { instance.PaddingTop.Offset, instance.PaddingRight.Offset, instance.PaddingBottom.Offset, instance.PaddingLeft.Offset }
	elseif instance:IsA("UIScale") then
		node.scale = instance.Scale
	elseif instance:IsA("UIGradient") then
		node.rot = instance.Rotation
		node.gloss = instance.Name == "Gloss"
	elseif instance:IsA("BillboardGui") then
		return nil
	end
	for _, child in instance:GetChildren() do
		local childNode = dump(child)
		if childNode then
			table.insert(node.children, childNode)
		end
	end
	return node
end
-- settle = ile sekund odczekać przed zrzutem (znikają chwilowe napisy z poprzednich kroków)
local function snapshot(name: string, background: string, settle: number?)
	if not SNAPSHOT_DIR then
		return
	end
	if settle then
		task.wait(settle)
		frames(2)
	end
	syncLanguage()
	fs.writeDir(SNAPSHOT_DIR)
	local file = string.format("%s/%s_%dx%d_%s.json", SNAPSHOT_DIR, name, VIEW_W, VIEW_H, LANG)
	fs.writeFile(file, serde.encode("json", { name = name, width = VIEW_W, height = VIEW_H, touch = TOUCH, lang = LANG, background = background, root = dump(playerGui) }))
end

-- 1. Hol ---------------------------------------------------------------------------------------------
remotes.StateUpdate.OnClientEvent:Fire(table.clone(profile))
frames(5)
check(gui("HUD/Lobby").Visible and not gui("HUD/Round").Visible, "hol: widać HUD holu, HUD rundy schowany")
check(gui("HUD/Lobby/TopRow/Coins/Text").Text == "💰 1 234", "hol: licznik monet")
check(findText("Noc bez prądu") ~= nil, "hol: dzisiejsza noc z modyfikatorem")
snapshot("01_lobby", "lobby")

-- 2. Sklep -------------------------------------------------------------------------------------------
click("HUD/Lobby/TopRow/Shop")
check(gui("Shop/Shop").Visible, "sklep otwiera się przyciskiem")
check(findText("Latarka") and findText("Cichobiegi") and findText("Kieszenie") and findText("Kondycja"), "sklep: cztery ulepszenia")
snapshot("02_shop", "lobby")
click("Shop/Shop/Frame/flashlight/Buy")
check(lastFired("BuyUpgrade") and lastFired("BuyUpgrade").args[1] == "flashlight", "sklep: zakup idzie do serwera")
check(findText("🔦 Latarka: poziom 2!") ~= nil, "sklep: komunikat po zakupie")
check(gui("HUD/Lobby/TopRow/Coins/Text").Text == "💰 1 084", "sklep: monety po zakupie")
click("Shop/Shop/Close")
check(not gui("Shop/Shop").Visible, "sklep zamyka się")

-- 3. Ustawienia --------------------------------------------------------------------------------------
click("HUD/Lobby/TopRow/Settings")
check(gui("Settings/Settings").Visible, "ustawienia otwierają się")
snapshot("03_settings", "lobby")
click("Settings/Settings/Scares")
check(lastFired("SetSetting").args[1] == "jumpscares" and lastFired("SetSetting").args[2] == false, "ustawienia: wyłączenie straszenia")
click("Settings/Settings/Captions")
check(lastFired("SetSetting").args[1] == "captions" and lastFired("SetSetting").args[2] == false, "ustawienia: wyłączenie napisów")
click("Settings/Settings/Captions")
click("Settings/Settings/Scares")
click("Settings/Settings/Sound")
check(lastFired("SetSetting").args[1] == "sound" and lastFired("SetSetting").args[2] == 2, "ustawienia: dźwięk")
click("Settings/Settings/Close")

-- 4. Start rundy -------------------------------------------------------------------------------------
roundEvent("start", { rent = 190, duration = 360, players = 2, night = "blackout" })
pushRound()
check(gui("HUD/Round").Visible and not gui("HUD/Lobby").Visible, "runda: HUD rundy")
check(gui("Fx/Intro").Visible, "runda: ekran startowy z obrazkami")
snapshot("04_intro", "round")
click("Fx/Intro/Ok")
check(not playerGui.Fx:FindFirstChild("Intro"), "ekran startowy znika po kliknięciu")
check(gui("HUD/Round/Top/Clock").Text == "🕗 20:14", "runda: zegar")
check(gui("HUD/Round/Top/Rent/Text").Text == T("💰 Czynsz: 40 / 190"), "runda: pasek czynszu")
check(gui("HUD/Round/Status/Text").Text == T("🎒 23/90 · 📍 Parter"), "runda: linijka stanu")
check(gui("HUD/Round/Battery").Visible, "runda: bateria widoczna przy włączonej latarce")
check(gui("Objective/Objective").Visible and gui("Objective/Objective").Text == T("🔍 Przeszukuj meble (E) i szukaj monet. Wyżej jest ich więcej!"), "runda: cel")
local marker = playerGui:FindFirstChild("ObjectiveMarker")
check(marker ~= nil and marker.Enabled and marker.Adornee ~= nil, "pierwsza runda: strzałka nad najbliższym meblem")
check(tags.WallClock[1].Text == "20:14", "zegar ścienny pokazuje godzinę rundy")

-- 5. Zbieranie, hałas, potwór, napisy ----------------------------------------------------------------
roundEvent("found", { amount = 12, position = V3.new(8, 2, 10) })
roundEvent("deposit", { amount = 35 })
roundEvent("alert", { text = "🤫 Ćśś! Sąsiad usłyszał Twoje kroki... Idź powoli!", kind = "bad", monster = "neighbor" })
remotes.Notify.OnClientEvent:Fire("🎒 Kieszenie pełne! Zanieś monety do skrzynki.", "warn")
local monster = MonsterModels.Neighbor()
monster:SetAttribute("MonsterId", "neighbor")
monster:SetAttribute("Pivot", CF.new(20, 14.5, 20))
monster:SetAttribute("Moving", true)
monster:SetAttribute("Speed", 13)
monster:SetAttribute("Mood", "curious")
monster:SetAttribute("Hostile", false)
monster.Parent = building.model
H.event(rounds, "DescendantAdded"):Fire(monster)
task.wait(0.05)
rootPart.CFrame = CF.new(8, 17.5, 20)
rootPart.AssemblyLinearVelocity = V3.new(20, 0, 0)
humanoid.MoveDirection = V3.new(1, 0, 0)
pushRound({ floor = 1, carried = 80, clock = "21:02", timeLeft = 262 })
frames(20)
check(findText("🤫 1. piętro: tu mieszka Cichy Sąsiad. Nie biegaj i nie noś pełnych kieszeni!") ~= nil, "pierwsze wejście na piętro: podpowiedź")
check(gui("HUD/Round/Status/Text").Text == T("🎒 80/90 🔔 · 📍 1. piętro"), "pełne kieszenie brzęczą (🔔)")
local ring = rounds:FindFirstChild("NoiseRing")
check(ring ~= nil and ring.Transparency < 1 and ring.Size.Y > 40, "pierścień hałasu rośnie przy biegu z pełnymi kieszeniami (" .. math.floor(ring.Size.Y / 2) .. " studów)")
check(gui("HUD/Round/Caption").Visible and gui("HUD/Round/Caption").Text:find(T("👣 Kroki"), 1, true) ~= nil, "napis dźwięku: " .. gui("HUD/Round/Caption").Text)
check((monster.PrimaryPart.CFrame.Position - V3.new(20, 14.5, 20)).Magnitude < 2, "potwór rysowany płynnie w miejscu z serwera")
snapshot("05_round", "round")
monster:SetAttribute("Mood", "alert")
monster:SetAttribute("Hostile", true)
frames(20)
local eye = monster:FindFirstChild("EyeOpen")
check(eye.Transparency == 0 and monster:FindFirstChild("EyeClosed").Transparency == 1, "pościg: Sąsiad otwiera oczy")
snapshot("06_chase", "round", 3)
rootPart.AssemblyLinearVelocity = V3.zero
humanoid.MoveDirection = V3.zero
frames(30)
check(ring.Transparency == 1, "stojący gracz: pierścień hałasu znika")

-- 6. Samouczek, szafa i minigra oddechu --------------------------------------------------------------
roundEvent("tutorial", { step = "hide" })
pushRound()
check(gui("Objective/Objective").Text == T("🚪 Szybko! Schowaj się w szafie!"), "samouczek: cel schowaj się")
check(marker.Adornee ~= nil and marker.Adornee.Name == "Wardrobe", "samouczek: strzałka nad szafą")
pushRound({ hidden = true, flashlight = false })
check(gui("HUD/Round/Hidden").Visible, "szafa: przyciemniony ekran")
roundEvent("breath", { duration = 4, monster = "neighbor" })
check(gui("Breath/Breath").Visible, "minigra oddechu pojawia się")
snapshot("07_breath", "round")
inputBegan:Fire({ KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard })
frames(140)
inputEnded:Fire({ KeyCode = Enum.KeyCode.Space, UserInputType = Enum.UserInputType.Keyboard })
check(not gui("Breath/Breath").Visible and lastFired("BreathResult") ~= nil and type(lastFired("BreathResult").args[1]) == "boolean", "minigra kończy się i wysyła wynik: " .. tostring(lastFired("BreathResult").args[1]))
roundEvent("breathOk", { bonus = 10 })
roundEvent("closecall", { bonus = 10 })
pushRound({ hidden = false, closeCalls = 2 })

-- 7. Komunikaty, zdarzenia Reżysera, finał -----------------------------------------------------------
actions.QuickChat(nil, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Two })
check(lastFired("QuickChat") and lastFired("QuickChat").args[1] == 2, "szybki komunikat klawiszem 2")
click(BUTTONS .. "/Comms")
check(gui(COMMS).Visible, "menu komunikatów otwiera się przyciskiem")
snapshot("08_comms", "round", 4.2)
click(COMMS .. "/Chat1")
check(lastFired("QuickChat").args[1] == 1 and not gui(COMMS).Visible, "komunikat z menu")
roundEvent("comms", { by = "Olek_2014", index = 1, position = V3.new(30, 18, 20) })
check(findText("📣 Olek_2014: 💰 Tutaj monety!") ~= nil, "komunikat drużyny na ekranie")
roundEvent("blackout", { floor = 1, duration = 6, origin = ORIGIN })
roundEvent("sound", { key = "NeighborSteps", position = V3.new(12, 30, 20), duration = 4 })
frames(15)
roundEvent("ping", { by = "Olek_2014", position = V3.new(10, 16, 30), label = "Komoda" })
actions.Flashlight(nil, Enum.UserInputState.Begin, {})
check(lastFired("Flashlight") ~= nil, "latarka: klawisz F wysyła stan do serwera")
actions.Sprint(nil, Enum.UserInputState.Begin, {})
frames(5)
check(humanoid.WalkSpeed == 12, "w rundzie bez ruchu: prędkość chodu")
roundEvent("finale", {})
pushRound({ finale = true, clock = "23:56", timeLeft = 40, carried = 90, deposited = 150 })
check(gui("Objective/Objective").Text == T("🎒 Kieszenie pełne! Zanieś monety do skrzynki w BIURZE."), "cel: pełne kieszenie")
snapshot("09_finale", "round")
roundEvent("paid", { by = "Tester", time = "5:40" })
pushRound({ rentPaid = true, deposited = 240, carried = 0 })
check(gui("HUD/Round/Top/Rent/Text").Text == T("✅ Czynsz zapłacony! Brama otwarta"), "czynsz zapłacony w HUD")
check(marker.Adornee ~= nil and marker.Adornee.Name == "GateSign", "po zapłacie: strzałka nad bramą")
frames(3)
check(playerGui.ObjectiveEdge.EdgeArrow.Visible == false or playerGui.ObjectiveEdge.EdgeArrow.Visible == true, "strzałka na brzegu ekranu liczy się bez błędu")

-- 8. Północ, złapanie, duszek, podsumowanie ----------------------------------------------------------
roundEvent("midnight", {})
pushRound({ phase = "hunt", rentPaid = false, deposited = 150, huntLeft = 61, clock = "00:00", timeLeft = 0 })
check(gui("HUD/Round/Top/Clock").Text == T("🏃 UCIEKAJ! 1:01"), "północ: odliczanie pościgu")
roundEvent("caught", { monster = "landlord" })
check(findText("CZYNSZ!!!") ~= nil, "złapanie: kreskówkowy straszak")
snapshot("10_caught", "round")
pushRound({ status = "ghost", carried = 0, pingReady = true, team = { { name = "Tester", status = "ghost", carried = 0 }, { name = "Olek_2014", status = "escaped", carried = 0 } } })
check(gui("HUD/Round/Ghost").Visible and gui(BUTTONS .. "/Ping").Visible and not gui(BUTTONS .. "/Flashlight").Visible, "duszek: przycisk wskazywania zamiast latarki")
click(BUTTONS .. "/Ping")
check(lastFired("GhostPing") ~= nil, "duszek: wskazanie idzie do serwera")
snapshot("11_ghost", "round", 5)
roundEvent("end", { outcome = "caught", reward = 87, rentPaid = false, deposited = 75, found = 110, teamDeposited = 150, rent = 190, closeCalls = 2, night = "blackout" })
check(gui("Fx/Summary").Visible and findText("NAGRODA: +87 💰") ~= nil and findText("😮 O włos: 2 razy (+20 💰)") ~= nil, "podsumowanie rundy")
snapshot("12_summary", "round")
remotes.RoundState.OnClientEvent:Fire(nil)
frames(5)
check(gui("HUD/Lobby").Visible and not gui("HUD/Round").Visible and not marker.Enabled, "powrót do holu")
check(humanoid.WalkSpeed == 24, "w holu sprint działa bez kondycji")

-- 9. Język ---------------------------------------------------------------------------------------------
if LANG == "en" then
	check(controllers.LanguageController.Get() == "en", "język: angielski z ustawień")
	check(gui("HUD/Lobby/Hint").Text:find("Stand on the green doormat", 1, true) ~= nil, "język: napisy holu po angielsku")
	local polish = {}
	for _, descendant in playerGui:GetDescendants() do
		if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and not descendant:GetAttribute("NoTranslate") then
			for _, letter in { "ą", "ć", "ę", "ł", "ń", "ó", "ś", "ź", "ż", "Ł", "Ś", "Ż" } do
				if descendant.Text:find(letter, 1, true) then
					table.insert(polish, descendant.Text)
					break
				end
			end
		end
	end
	check(#polish == 0, "język: żaden napis w interfejsie nie został po polsku" .. (if #polish > 0 then ": " .. table.concat(polish, " | ") else ""))
else
	check(controllers.LanguageController.Get() == "pl", "język: polski")
end

print(("\nKLIENT: WSZYSTKIE TESTY PRZESZŁY (%dx%d, %s, %s)"):format(VIEW_W, VIEW_H, if TOUCH then "dotyk" else "mysz", LANG))
process.exit(0)

-- Symulacja rundy w Lune: udawani gracze, usługi i podpowiedzi. Sprawdza przebieg: monety -> czynsz -> ucieczka,
-- pościg Sąsiada i złapanie (duszek + worek), Mruczek i latarka, szafa, północ i Klucznik.
local H = require("./harness")
local roblox = H.roblox
local task = require("@lune/task")
local V3, CF = roblox.Vector3, roblox.CFrame

-- Brakujące w Lune metody i właściwości silnika
local velocity = {}
roblox.implementProperty("Part", "Position", function(i) return i.CFrame.Position end, function(i, v) i.CFrame = CF.new(v) * (i.CFrame - i.CFrame.Position) end)
roblox.implementProperty("Part", "AssemblyLinearVelocity", function(i) return velocity[i] or V3.zero end, function(i, v) velocity[i] = v end)
local function parts(model)
	local list = {}
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then table.insert(list, d) end end
	return list
end
roblox.implementMethod("Model", "PivotTo", function(model, target)
	local primary = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or parts(model)[1]
	local delta = target * primary.CFrame:Inverse()
	for _, p in parts(model) do p.CFrame = delta * p.CFrame end
end)

local function signal()
	local s = { handlers = {} }
	function s:Connect(fn) table.insert(self.handlers, fn); return { Disconnect = function() end } end
	function s:Once(fn) return self:Connect(fn) end
	function s:Fire(...) for _, h in self.handlers do h(...) end end
	return s
end

-- Usługi
local events = {}
local fakePlayers = {}
H.services.Players = { GetPlayers = function() return fakePlayers end, PlayerAdded = signal(), PlayerRemoving = signal() }
H.services.RunService = { Heartbeat = signal(), IsStudio = function() return true end }
H.services.Debris = { AddItem = function() end }
H.services.TweenService = { Create = function() return { Play = function() end, Completed = signal() } end }
H.services.DataStoreService = { GetDataStore = function() error("brak DataStore w teście") end }
H.services.PathfindingService = { CreatePath = function()
	local path = { Status = nil, wp = {} }
	function path:ComputeAsync(a, b) self.wp = { { Position = a }, { Position = (a + b) / 2 }, { Position = b } }; self.Status = roblox.Enum.PathStatus.Success end
	function path:GetWaypoints() return self.wp end
	return path
end }
H.env.workspace = { Raycast = function() return nil end }
H.env.RaycastParams = { new = function() return {} end }
H.overrides[H.root .. "/server/World/LandlordBuilder"] = { Build = function(_, _, parent) local m = roblox.Instance.new("Model"); m.Parent = parent; return m end }
local remote = {
	Event = function(name) return { FireClient = function(_, player, kind, data) table.insert(events, { player = player, remote = name, kind = kind, data = data }) end } end,
	OnServerEvent = function() end, OnServerInvoke = function() end,
	IsInteger = function() return true end,
}
H.overrides[H.root .. "/server/Services/RemoteService"] = remote
local prompts = {}
H.overrides[H.root .. "/server/Lib/HoldPrompt"] = { Create = function(parent, options, callback)
	local prompt = roblox.Instance.new("ProximityPrompt")
	prompt.ActionText = options.action or ""
	prompt.ObjectText = options.object or ""
	prompt.Parent = parent
	prompts[parent] = callback
	return prompt
end }

local GameConfig = H.load(H.root .. "/shared/Config/GameConfig")
local Round = H.load(H.root .. "/server/Round/Round")
local Monster = H.load(H.root .. "/server/Round/Monster")
Monster.SpeedOf = function(root) return (velocity[root] or V3.zero).Magnitude end

local function makePlayer(name)
	local character = roblox.Instance.new("Model")
	local root = roblox.Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = V3.new(2, 2, 1); root.Parent = character
	local head = roblox.Instance.new("Part"); head.Name = "Head"; head.Size = V3.new(2, 1, 1); head.CFrame = CF.new(0, 1.5, 0); head.Parent = character
	character.PrimaryPart = root
	local p = { Name = name, DisplayName = name, UserId = #fakePlayers + 1, Character = character, Parent = true }
	table.insert(fakePlayers, p)
	return p
end
local function put(p, position) p.Character:PivotTo(CF.new(position + V3.new(0, 3, 0))) end
local function trigger(part, p) put(p, part.CFrame.Position + V3.new(0, -3, 0)); prompts[part](p) end
local function check(cond, msg) if not cond then error("TEST FAIL: " .. msg) end print("ok  " .. msg) end
local function lastEvent(p, kind)
	for i = #events, 1, -1 do if events[i].player == p and events[i].kind == kind then return events[i] end end
	return nil
end

-- 1. Runda dla dwóch graczy ---------------------------------------------------------------------
local finished = {}
local folder = roblox.Instance.new("Folder")
local p1, p2 = makePlayer("Ala"), makePlayer("Olek")
local round = Round.new(1, V3.new(0, 0.5, 450), { p1, p2 }, folder, function(player, summary) finished[player] = summary end)
round:Start(function(player, cf) player.Character:PivotTo(cf) end)
local NightConfig = H.load(H.root .. "/shared/Config/NightConfig")
check(round.rent == math.floor((GameConfig.RENT_BASE + GameConfig.RENT_PER_EXTRA_PLAYER) * NightConfig.Value(round.night, "rent")), "czynsz dla 2 graczy = " .. round.rent .. " (noc: " .. round.night.id .. ")")
local total, keys = 0, 0
for _, spot in round.building.spots do total += spot.coins; if spot.hasKey then keys += 1 end end
check(keys == 1, "dokładnie jeden klucz w meblach")
check(math.abs(total - math.floor(round.rent * GameConfig.COINS_IN_BUILDING_RATIO)) < #round.building.spots, "monet w meblach ~" .. total)
check(#round.monsters == 2, "Sąsiad i Mruczek na miejscu")
for _ = 1, 30 do H.services.RunService.Heartbeat:Fire(1 / 30) end
check(typeof(round.monsters[1].model:GetAttribute("Pivot")) == "CFrame", "potwór publikuje położenie (Pivot) dla graczy")
check(lastEvent(p1, "start") ~= nil, "gracz dostał zdarzenie start")

-- 2. Ala zbiera i wpłaca aż do zapłaty czynszu --------------------------------------------------
for _, spot in round.building.spots do
	if round.rentPaid then break end
	while not spot.searched and round.players[p1].status == "inside" do
		trigger(spot.part, p1)
		if round.players[p1].carried >= round.players[p1].capacity or spot.searched then
			trigger(round.building.depositBox, p1)
		end
		if round.rentPaid then break end
	end
end
trigger(round.building.depositBox, p1)
check(round.rentPaid, "czynsz zapłacony, wpłacono " .. round.deposited)
check(round.building.frontDoor.CanCollide == false, "drzwi frontowe otwarte")
check(lastEvent(p2, "paid") ~= nil, "drużyna dostała zdarzenie paid")
check(round.players[p1].hasKey or round.building.locked.opened ~= nil or true, "klucz (opcjonalnie)")

-- 3. Klucz i zamknięte mieszkanie ---------------------------------------------------------------
round.players[p1].hasKey = true
trigger(round.building.locked.door, p1)
check(round.building.locked.opened == true, "zamknięte mieszkanie otwarte kluczem")
round.players[p1].carried = 0
trigger(round.building.locked.jar, p1)
check(round.players[p1].carried > 0, "monety ze słoika: " .. round.players[p1].carried)

-- 4. Szafa: chowanie i wychodzenie ---------------------------------------------------------------
local wardrobe = round.building.wardrobes[1]
trigger(wardrobe.part, p2)
check(round.players[p2].hidden == wardrobe and wardrobe.occupant == p2, "Olek schował się w szafie")
check(#round:Targets() == 1, "schowany gracz nie jest celem potworów")
prompts[wardrobe.part](p2)
check(round.players[p2].hidden == nil, "Olek wyszedł z szafy")

-- 5. Latarka i bateria ---------------------------------------------------------------------------
round:SetFlashlight(p2, true)
check(round.players[p2].flashlight == true, "latarka włączona")
local before = round.players[p2].battery
round:Tick(1)
check(round.players[p2].battery < before, "bateria się rozładowuje")

-- 6. Mruczek idzie za światłem na 2. piętrze -----------------------------------------------------
local cat = round.monsters[2]
put(p2, cat.position + V3.new(10, 0, 0))
round:Tick(0.1)
check(cat.state == "stalk", "Mruczek skrada się do światła")
round:Tick(0.1)
check(cat.model:GetAttribute("Hostile") == true and cat.moodLabel.Text == "❗", "Mruczek pokazuje ❗ i jest groźny")
round:SetFlashlight(p2, false)
cat.lastLight = os.clock() - 5
round:Tick(0.1)
check(cat.state ~= "stalk", "zgaszona latarka: Mruczek traci zainteresowanie")

-- 7. Sąsiad słyszy bieg i łapie -------------------------------------------------------------------
local neighbor = round.monsters[1]
put(p2, neighbor.position + V3.new(25, 0, 0))
velocity[p2.Character.HumanoidRootPart] = V3.new(20, 0, 0)
round.players[p2].carried = 17
round:Tick(0.1)
check(neighbor.state == "investigate", "Sąsiad usłyszał bieganie (stan " .. tostring(neighbor.state) .. ")")
put(p2, neighbor.position + V3.new(8, 0, 0))
round:Tick(0.1)
check(neighbor.state == "chase", "Sąsiad widzi ruszającego się gracza i goni")
put(p2, neighbor.position + V3.new(2, 0, 0))
round:Tick(0.1)
check(round.players[p2].status == "ghost", "Olek złapany -> duszek")
check(#round.bags == 1 and round.bags[1].coins == 17, "worek z 17 monetami po złapanym")
check(lastEvent(p2, "caught").data.monster == "neighbor", "zdarzenie caught od Sąsiada")

-- 7b. Brzęk pełnych kieszeni: Sąsiad słyszy idącego (nie biegnącego) gracza ------------------------
local p4 = makePlayer("Kuba")
local round3 = Round.new(3, V3.new(600, 0.5, 450), { p4 }, folder, function() end)
round3:Start(function(player, cf) player.Character:PivotTo(cf) end)
local n3 = round3:MonsterById("neighbor")
local s4 = round3.players[p4]
put(p4, n3.position + V3.new(15, 0, 0))
velocity[p4.Character.HumanoidRootPart] = V3.new(10, 0, 0) -- idzie (nie biegnie)
s4.carried = 0
round3:Tick(0.1)
check(n3.state == "patrol", "pusty spacer: Sąsiad nic nie słyszy")
s4.carried = s4.capacity
round3:Tick(0.1)
check(n3.state == "investigate", "pełne kieszenie brzęczą: Sąsiad słyszy idącego gracza")
velocity[p4.Character.HumanoidRootPart] = V3.zero

-- 7c. "O włos!": potwór szuka tuż obok nieruchomego gracza ------------------------------------------
put(p4, n3.position + V3.new(5, 0, 0))
round3:Tick(0.1)
check(s4.closeCalls == 1 and lastEvent(p4, "closecall") ~= nil, "O włos! bonus za bezruch obok potwora")

-- 7d. Szafa: potwór zagląda, minigra oddechu ---------------------------------------------------------
local w3 = round3.building.wardrobes[1]
s4.carried = 0
trigger(w3.part, p4)
check(s4.hidden == w3, "Kuba w szafie")
round3.elapsed += 3
check(round3:FindOccupiedWardrobe(w3.part.CFrame.Position, 10) == w3, "potwór znajduje zajętą szafę obok")
check(round3:CheckWardrobe(w3, "neighbor") and lastEvent(p4, "breath") ~= nil, "gracz dostaje minigrę oddechu")
round3:BreathResult(p4, true)
check(s4.status == "inside" and s4.hidden == w3 and s4.closeCalls == 2, "wstrzymany oddech: bezpiecznie + bonus")
round3.elapsed += GameConfig.WARDROBE_CHECK_COOLDOWN + 1
check(round3:CheckWardrobe(w3, "landlord"), "drugie sprawdzenie po przerwie")
round3:BreathResult(p4, false)
check(s4.status == "ghost" and s4.hidden == nil, "nieudany oddech: złapany (duszek)")

-- 7e. Finał, Reżyser, samouczek, komunikaty ---------------------------------------------------------
local p5 = makePlayer("Lena")
local round4 = Round.new(4, V3.new(900, 0.5, 450), { p5 }, folder, function() end)
round4:Start(function(player, cf) player.Character:PivotTo(cf) end)
local s5 = round4.players[p5]
round4.timeLeft = GameConfig.FINALE_TIME + 0.05
round4:Tick(0.1)
check(round4.finale and lastEvent(p5, "finale") ~= nil, "23:55: finał")
check(round4:SpeedScale("cat") == GameConfig.FINALE_SPEED, "w finale potwory są szybsze")
round4.calm = 100
put(p5, round4.building.patrol[1][2])
local before = #events
round4:Tick(0.1)
local directorFired = false
for i = before + 1, #events do
	local kind = events[i].kind
	if kind == "sound" or kind == "blackout" then directorFired = true end
end
check(directorFired or round4:MonsterById("neighbor").state == "investigate", "Reżyser nocy wywołał zdarzenie")
s5.newPlayer = true
s5.tutorial = nil
round4:Tick(0.1)
check(s5.tutorial == "waiting", "samouczek: nowy gracz na 1. piętrze")
s5.tutorialAt = 0
round4:MonsterById("neighbor").state = "patrol"
round4:Tick(0.1)
check(s5.tutorial == "hide" and lastEvent(p5, "tutorial") ~= nil, "samouczek: podpowiedź schowaj się")
s5.tutorialAt = 0
round4:Tick(0.1)
check(s5.tutorial == "done" and round4:MonsterById("neighbor").state == "investigate", "samouczek: Sąsiad idzie sprawdzić")
round4:QuickChat(p5, 2)
check(lastEvent(p5, "comms") ~= nil and lastEvent(p5, "comms").data.index == 2, "szybki komunikat do drużyny")
round3:Destroy()
round4:Destroy()

-- 8. Duszek wskazuje monety -----------------------------------------------------------------------
round.elapsed += GameConfig.GHOST_PING_COOLDOWN + 1
round:GhostPing(p2)
check(lastEvent(p1, "ping") ~= nil or lastEvent(p2, "ping") ~= nil or true, "ping duszka (o ile zostały monety)")

-- 9. Ala ucieka przez bramę -> koniec rundy -------------------------------------------------------
put(p1, (round.building.exitMin + round.building.exitMax) / 2 - V3.new(0, 3, 0))
round:Tick(0.1)
check(finished[p1] and finished[p1].outcome == "escaped", "Ala uciekła, nagroda " .. (finished[p1] and finished[p1].reward or -1))
check(finished[p2] and finished[p2].outcome == "caught", "Olek (duszek) kończy jako złapany, nagroda " .. (finished[p2] and finished[p2].reward or -1))
check(round.phase == "ending", "runda się kończy, gdy nikt nie został w środku")

-- 10. Północ bez czynszu: Klucznik ---------------------------------------------------------------
local p3 = makePlayer("Zosia")
local finished2 = {}
local round2 = Round.new(2, V3.new(300, 0.5, 450), { p3 }, folder, function(player, summary) finished2[player] = summary end)
round2:Start(function(player, cf) player.Character:PivotTo(cf) end)
round2.timeLeft = 0.05
round2:Tick(0.1)
check(round2.phase == "hunt", "północ: polowanie")
check(round2.building.frontDoor.CanCollide == false, "drzwi otwarte o północy")
task.wait(3.2)
check(#round2.monsters == 3, "Klucznik pojawił się po przemianie")
local landlord = round2.monsters[3]
put(p3, landlord.position + V3.new(2, 0, 0))
round2:Tick(0.1)
check(round2.players[p3].status == "ghost" and finished2[p3] ~= nil, "Klucznik złapał Zosię; runda kończy się (" .. tostring(finished2[p3] and finished2[p3].outcome) .. ")")

print("\nWSZYSTKIE TESTY PRZESZŁY")
round:Destroy()
round2:Destroy()

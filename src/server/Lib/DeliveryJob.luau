-- Wspólna praca z dowozem jedzenia (kebaby na rowerze, pizza na skuterze).
-- Weź jedzenie (od razu z lady albo po minigrze przygotowania), wsiądź na pojazd zaparkowany przy lokalu (znika
-- z parkingu, paczka ląduje w koszyku/kufrze), zawieź pod wskazany dom, wróć i odstaw pojazd na jego miejsce,
-- dopiero wtedy weź kolejne zamówienie. Podpowiedzi przy pojazdach są w folderze sesji (widzi je tylko pracujący
-- gracz), parking jest wspólny. Serwer odrzuca dostawy szybsze niż pozwala prędkość (teleport).
-- Zamówienia są do końca zmiany; cel na 3 gwiazdki to levelConfig.deliveries (wszystkie ciepłe).
--
-- spec = {
--   jobId, site (model w JobSites), pickupPart (część lokalu, przy której bierze się jedzenie),
--   parked (nazwa zaparkowanych pojazdów), vehicle ("bike" | "moped"), carrier (część pojazdu na paczkę),
--   engineSound (klucz dźwięku w AssetsConfig albo nil), fx (rodzaj efektu CleanFx przy dostawie),
--   package = { name, size, color, material } (paczka niesiona i wożona), pile = { size, color, material, hidden },
--   texts = { take, takeAction, takeObject, takeGuide, mount, back, parkFirst, taken, mountAction, parkAction,
--             vehicleObject, mountLabel, deliver (z %d), deliverAction, icon },
--   prep (opcjonalnie) = { start(session, api), action(session, akcja, wartość, api), stop(session) }: minigra
--     przed wydaniem paczki; api.give(session) wydaje paczkę, api.progress(session, podpowiedź, extra) pokazuje postęp,
--   evaluate (opcjonalnie) = function(session, fraction) -> gwiazdki, gdy cel osiągnięty
-- }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local AssetsConfig = require(ReplicatedStorage.Shared.Config.AssetsConfig)
local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local HoldPrompt = require(ServerScriptService.Lib.HoldPrompt)
local ScooterBuilder = require(ServerScriptService.World.ScooterBuilder)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local StateService = require(Services.StateService)
local JobService = require(Services.JobService)

local DeliveryJob = {}

local SPEED_TOLERANCE = 1.6
local COLORS = {
	marker = Color3.fromRGB(255, 220, 60),
	markerRing = Color3.fromRGB(255, 255, 255),
}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function doorPosition(house: Model): Vector3
	return house.Body.DoorAttachment.WorldPosition
end

-- Wysokość HumanoidRootPart nad ziemią (do ustawienia postaci przy pojeździe)
local function rootHeight(humanoid: Humanoid, root: BasePart): number
	return if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
end

local function markerPart(parent: Instance?, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function DeliveryJob.Create(spec)
	local job = { JobId = spec.jobId }
	local CONFIG = JobsConfig.Jobs[spec.jobId]
	local texts = spec.texts
	local pickupPart = nil
	local houses = {}
	local rng = Random.new()
	-- Parking: { model, ground, parts = { [część] = przezroczystość }, guis, takenBy = sesja jadąca tym pojazdem }
	local spots = {}
	local activeSessions = {} -- [session] = true
	local spotUi = {
		mount = { action = texts.mountAction, label = texts.mountLabel },
		park = { action = texts.parkAction, label = "🅿️ Parking" },
	}
	local api = {}

	local function chooseHouse(session): Model
		local state = session.state
		local candidates = {}
		for _, house in houses do
			if house ~= state.lastHouse then
				table.insert(candidates, house)
			end
		end
		if session.levelConfig.far then
			table.sort(candidates, function(a, b)
				return (doorPosition(a) - pickupPart.Position).Magnitude > (doorPosition(b) - pickupPart.Position).Magnitude
			end)
			for i = #candidates, math.max(2, math.ceil(#candidates / 2)) + 1, -1 do
				table.remove(candidates, i)
			end
		end
		return candidates[rng:NextInteger(1, #candidates)]
	end

	local function report(session)
		local state = session.state
		if state.pile then
			local waiting = not state.carrying and not state.vehicle and not state.making
			JobService.SetGuideTarget(state.pile, if waiting then texts.takeGuide else nil)
		end
		if state.making then
			return -- minigra przygotowania sama pokazuje postęp (api.progress)
		end
		local hint
		if state.carrying and state.vehicle then
			hint = string.format(texts.deliver, state.target:GetAttribute("HouseNumber") or 0)
		elseif state.carrying then
			hint = texts.mount
		elseif state.vehicle then
			hint = texts.back
		else
			hint = texts.take
		end
		JobService.UpdateProgress(session, state.delivered, state.goal, hint)
	end

	-- Zaparkowany pojazd znika z parkingu, gdy ktoś na niego wsiądzie, i wraca po odstawieniu
	local function setParked(spot, visible: boolean)
		for piece, transparency in spot.parts do
			piece.Transparency = if visible then transparency else 1
		end
		for _, gui in spot.guis do
			gui.Enabled = visible
		end
	end

	-- Zsiadanie: pojazd wraca na swoje miejsce na parkingu, prędkość wraca do normy
	local function releaseVehicle(session)
		local state = session.state
		if state.vehicle then
			ScooterBuilder.Detach(state.vehicle)
			state.vehicle = nil
		end
		local character = session.player.Character
		if character then
			character:SetAttribute("Riding", nil)
		end
		local humanoid = getHumanoid(session.player)
		if humanoid then
			humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		end
		local spot = state.spot and spots[state.spot]
		if spot and spot.takenBy == session then
			spot.takenBy = nil
			setParked(spot, true)
		end
		state.spot = nil
	end

	local mount, park

	-- Podpowiedzi przy pojazdach dla każdej sesji: "Wsiądź" przy wolnych (gdy masz paczkę i idziesz pieszo),
	-- "Zaparkuj" przy własnym miejscu (gdy jedziesz bez paczki). Podpowiedzi są tworzone na nowo zamiast włączania
	-- Enabled, bo klient ukrywa cudze obiekty prac tylko przy ich dodaniu.
	local function refreshSpots()
		for session in activeSessions do
			local state = session.state
			for index, spot in spots do
				local wanted = nil
				if state.carrying and not state.vehicle and spot.takenBy == nil then
					wanted = "mount"
				elseif state.vehicle and not state.carrying and spot.takenBy == session then
					wanted = "park"
				end
				local ui = state.spotUi[index]
				if ui and ui.kind ~= wanted then
					if ui.prompt then
						ui.prompt:Destroy()
						ui.prompt = nil
					end
					if ui.billboard then
						ui.billboard:Destroy()
						ui.billboard = nil
					end
					ui.kind = wanted
					-- Przewodnik prowadzi do pojazdu (napis nad nim już jest, więc bez etykiety)
					JobService.SetGuideTarget(ui.anchor, if wanted then "" else nil)
					if wanted then
						ui.prompt = HoldPrompt.Create(ui.anchor, { action = spotUi[wanted].action, object = texts.vehicleObject, hold = 0.3, activation = 9, maxDistance = 13 }, function(player)
							if player ~= session.player or not JobService.IsActive(session) then
								return
							end
							if wanted == "mount" then
								mount(session, index)
							else
								park(session, index)
							end
						end)
						local billboard = Instance.new("BillboardGui")
						billboard.Size = UDim2.fromOffset(130, 40)
						billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
						billboard.AlwaysOnTop = true
						local label = Instance.new("TextLabel")
						label.Size = UDim2.fromScale(1, 1)
						label.BackgroundTransparency = 1
						label.Font = Enum.Font.FredokaOne
						label.TextScaled = true
						label.TextColor3 = COLORS.marker
						label.Text = spotUi[wanted].label
						label.Parent = billboard
						local stroke = Instance.new("UIStroke")
						stroke.Thickness = 2
						stroke.Parent = label
						billboard.Parent = ui.anchor
						ui.billboard = billboard
					end
				end
			end
		end
	end

	local function clearDelivery(state)
		if state.box then
			state.box:Destroy()
			state.box = nil
		end
		if state.marker then
			state.marker:Destroy()
			state.marker = nil
		end
		state.carrying = false
	end

	local function onDeliver(session, player: Player)
		local state = session.state
		if player ~= session.player or not JobService.IsActive(session) or not state.carrying or not state.marker then
			return
		end
		local now = os.clock()
		local elapsed = math.max(now - state.pickedAt, 0.1)
		local flat = state.marker.Position - state.pickupPosition
		local distance = Vector3.new(flat.X, 0, flat.Z).Magnitude
		if distance / elapsed > CONFIG.walkSpeed * SPEED_TOLERANCE then
			warn(string.format("[%s] %s: za szybka dostawa (%.0f studs w %.1f s)", spec.jobId, player.Name, distance, elapsed))
			return
		end
		state.delivered += 1
		if elapsed <= CONFIG.hotTime then
			state.hot += 1
		end
		RemoteService.Event(RemoteNames.Events.CleanFx):FireClient(player, state.marker.Position, spec.fx, 1)
		clearDelivery(state)
		refreshSpots()
		report(session)
	end

	-- Znacznik dostawy: okrągła mata pod drzwiami z białą obwódką i cienki słup światła widoczny z daleka
	local function spawnMarker(session, house: Model)
		local state = session.state
		local number = tostring(house:GetAttribute("HouseNumber"))
		local ground = doorPosition(house) - Vector3.new(0, 2.8, 0)
		local flat = CFrame.Angles(0, 0, math.rad(90))
		local marker = markerPart(nil, "DeliveryMarker", Vector3.new(0.12, 5, 5), CFrame.new(ground + Vector3.new(0, 0.12, 0)) * flat, COLORS.marker, Enum.Material.SmoothPlastic)
		markerPart(marker, "Ring", Vector3.new(0.1, 5.8, 5.8), CFrame.new(ground + Vector3.new(0, 0.08, 0)) * flat, COLORS.markerRing, Enum.Material.SmoothPlastic)
		local beam = markerPart(marker, "Beam", Vector3.new(24, 0.8, 0.8), CFrame.new(ground + Vector3.new(0, 12, 0)) * flat, COLORS.marker, Enum.Material.Neon)
		beam.Transparency = 0.6

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(170, 50)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = marker
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = COLORS.marker
		label.Text = texts.icon .. "   Dom nr " .. number -- trzy spacje: Lang tłumaczy części osobno
		label.Parent = billboard
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label

		local promptPoint = Instance.new("Attachment")
		promptPoint.Name = "PromptPoint"
		promptPoint.Parent = marker
		promptPoint.WorldPosition = ground + Vector3.new(0, 3, 0)
		HoldPrompt.Create(promptPoint, { action = texts.deliverAction, object = "Dom nr " .. number, hold = 0.5, activation = 10, maxDistance = 14 }, function(player)
			onDeliver(session, player)
		end)
		JobService.SetGuideTarget(marker, "")
		marker.Parent = session.folder
		state.marker = marker
	end

	-- Wsiadanie: postać siada w miejscu zaparkowanego pojazdu (przodem tam, gdzie on), pojazd znika z parkingu,
	-- a paczka przechodzi z rąk do koszyka/kufra. Dopiero teraz pojawia się znacznik domu.
	mount = function(session, index: number)
		local state = session.state
		local spot = spots[index]
		local character = session.player.Character
		local humanoid = getHumanoid(session.player)
		local root = getRoot(session.player)
		if not spot or not state.carrying or state.vehicle or not character or not humanoid or not root then
			return
		end
		if spot.takenBy ~= nil then
			StateService.Notify(session.player, texts.taken, "info")
			return
		end
		character:PivotTo(spot.ground * CFrame.new(0, rootHeight(humanoid, root), 0.9))
		local ride = ScooterBuilder.Attach(character, spec.vehicle)
		if not ride then
			return
		end
		spot.takenBy = session
		state.spot = index
		setParked(spot, false)
		local soundId = spec.engineSound and AssetsConfig.Sounds[spec.engineSound]
		if type(soundId) == "string" and soundId ~= "" then
			local engine = Instance.new("Sound")
			engine.Name = "Engine"
			engine.SoundId = soundId
			engine.Looped = true
			engine.Volume = AssetsConfig.Volumes[spec.engineSound] or 0.35
			engine.RollOffMaxDistance = 50
			engine.Parent = ride.model.PrimaryPart
			engine:Play()
		end
		character:SetAttribute("Riding", true)
		state.vehicle = ride
		humanoid.WalkSpeed = CONFIG.walkSpeed
		local carrier = ride.model:FindFirstChild(spec.carrier)
		if state.box and carrier then
			state.box:ClearAllChildren()
			state.box.CFrame = carrier.CFrame * CFrame.new(0, carrier.Size.Y / 2 + state.box.Size.Y / 2, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = carrier
			weld.Part1 = state.box
			weld.Parent = state.box
		end
		spawnMarker(session, state.target)
		refreshSpots()
		report(session)
	end

	-- Parkowanie: pojazd wraca na swoje miejsce, postać staje obok
	park = function(session, index: number)
		local state = session.state
		local spot = spots[index]
		if not spot or state.carrying or not state.vehicle or state.spot ~= index then
			return
		end
		releaseVehicle(session)
		local character = session.player.Character
		local humanoid = getHumanoid(session.player)
		local root = getRoot(session.player)
		if character and humanoid and root then
			character:PivotTo(spot.ground * CFrame.new(2.6, rootHeight(humanoid, root), 0))
		end
		refreshSpots()
		report(session)
	end

	-- Wydanie paczki: niesiona przed postacią (po wsiadnięciu przechodzi do koszyka/kufra), wybór domu
	function api.give(session)
		local state = session.state
		local root = getRoot(session.player)
		if not root or state.carrying then
			return
		end
		state.making = nil
		state.carrying = true
		state.pickedAt = os.clock()
		state.pickupPosition = pickupPart.Position
		state.target = chooseHouse(session)
		state.lastHouse = state.target
		local box = Instance.new("Part")
		box.Name = spec.package.name
		box.Size = spec.package.size
		box.Color = spec.package.color
		box.Material = spec.package.material
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Massless = true
		box.CFrame = root.CFrame * CFrame.new(0, 0.2, -1.5)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = box
		weld.Parent = box
		box.Parent = session.folder
		state.box = box
		refreshSpots()
		report(session)
	end

	function api.progress(session, hint: string, extra)
		local state = session.state
		JobService.UpdateProgress(session, state.delivered, state.goal, hint, extra)
	end

	local function onPickup(session, player: Player)
		local state = session.state
		if player ~= session.player or not JobService.IsActive(session) or state.carrying or state.making then
			return
		end
		if state.vehicle then
			StateService.Notify(player, texts.parkFirst, "warn")
			return
		end
		if spec.prep then
			spec.prep.start(session, api)
			report(session)
		else
			api.give(session)
		end
	end

	function job.Init()
		local sites = Workspace.Map.JobSites
		local site = sites:WaitForChild(spec.site)
		pickupPart = site:WaitForChild(spec.pickupPart)
		for _, house in sites:WaitForChild("Houses"):GetChildren() do
			if house:IsA("Model") and house:FindFirstChild("Body") then
				table.insert(houses, house)
			end
		end
		for _, child in site:GetChildren() do
			if child.Name == spec.parked and child.PrimaryPart then
				local spot = { model = child, ground = ScooterBuilder.GroundOf(child), parts = {}, guis = {} }
				for _, descendant in child:GetDescendants() do
					if descendant:IsA("BasePart") then
						spot.parts[descendant] = descendant.Transparency
					elseif descendant:IsA("SurfaceGui") then
						table.insert(spot.guis, descendant)
					end
				end
				table.insert(spots, spot)
			end
		end
	end

	function job.StartShift(session)
		local state = session.state
		state.goal = session.levelConfig.deliveries
		state.delivered = 0
		state.hot = 0
		state.carrying = false

		-- Jedzenie na ladzie (albo niewidoczny punkt nad stołem, gdy najpierw trzeba je przygotować)
		local pile = Instance.new("Part")
		pile.Name = "FoodPile"
		pile.Size = spec.pile.size
		pile.CFrame = pickupPart.CFrame * CFrame.new(0, pickupPart.Size.Y / 2 + spec.pile.size.Y / 2, 0)
		pile.Color = spec.pile.color
		pile.Material = spec.pile.material
		pile.Transparency = if spec.pile.hidden then 1 else 0
		pile.Anchored = true
		pile.CanCollide = false
		HoldPrompt.Create(pile, { action = texts.takeAction, object = texts.takeObject, hold = 0.5, activation = 10, maxDistance = 14 }, function(player)
			onPickup(session, player)
		end)
		pile.Parent = session.folder
		state.pile = pile

		-- Niewidoczne punkty przy pojazdach na parkingu: tu pojawiają się podpowiedzi "Wsiądź" / "Zaparkuj"
		state.spotUi = {}
		for index, spot in spots do
			local anchor = Instance.new("Part")
			anchor.Name = "VehicleSpot"
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.CFrame = spot.ground * CFrame.new(0, 2.5, 0)
			anchor.Transparency = 1
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Parent = session.folder
			state.spotUi[index] = { anchor = anchor }
		end
		activeSessions[session] = true

		report(session)
	end

	function job.OnAction(session, action: string, value: any)
		if spec.prep and spec.prep.action and session.state.making then
			spec.prep.action(session, action, value, api)
		end
	end

	function job.Cleanup(session)
		activeSessions[session] = nil
		if spec.prep and spec.prep.stop then
			spec.prep.stop(session)
		end
		clearDelivery(session.state)
		releaseVehicle(session)
		refreshSpots()
	end

	-- 3 gwiazdki: cel osiągnięty i co najmniej tyle ciepłych dostaw, ile wynosi cel
	function job.Evaluate(session): number
		local state = session.state
		local fraction = state.delivered / state.goal
		if fraction >= 1 then
			if spec.evaluate then
				return spec.evaluate(session)
			end
			return if state.hot >= state.goal then 3 else 2
		end
		return math.min(2, JobService.StarsFromFraction(fraction))
	end

	return job
end

return DeliveryJob

-- Płynny ruch potworów u gracza: serwer wysyła położenie ~15 razy na sekundę (atrybut Pivot), a tutaj
-- co klatkę wygładzamy ruch, dodajemy kołysanie przy chodzeniu i animujemy części (MonsterAnimations).
-- Dzięki temu potwór nie szarpie nawet przy słabszym internecie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonsterAnimations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("MonsterAnimations"))

local MonsterRenderer = {}

local SMOOTHING = 10 -- im więcej, tym szybciej model dogania położenie z serwera
local MAX_DISTANCE = 220 -- dalszych potworów nie animujemy

local tracked = {} -- [Model] = { current, t, parts }

local function track(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local id = model:GetAttribute("MonsterId")
	local root = model.PrimaryPart
	if not id or not root then
		return
	end
	local parts = {}
	local alertParts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			for _, def in MonsterAnimations[id] or {} do
				if descendant.Name == def.part then
					local hinge = if def.hinge then model:GetAttribute("Hinge" .. def.hinge) else nil
					table.insert(parts, {
						part = descendant,
						base = root.CFrame:ToObjectSpace(descendant.CFrame),
						hinge = if typeof(hinge) == "Vector3" then CFrame.new(hinge) else nil,
						fn = def.fn,
					})
				end
			end
			local alert = descendant:GetAttribute("Alert")
			if alert then
				table.insert(alertParts, { part = descendant, show = alert == "show" })
			end
		end
	end
	tracked[model] = { current = nil, t = math.random() * 10, parts = parts, alertParts = alertParts, alert = nil }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			tracked[model] = nil
		end
	end)
end

local function render(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local alpha = 1 - math.exp(-dt * SMOOTHING)
	for model, entry in tracked do
		local target = model:GetAttribute("Pivot")
		if typeof(target) ~= "CFrame" then
			continue
		end
		if (target.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			entry.current = target
			continue
		end
		entry.current = if entry.current then entry.current:Lerp(target, alpha) else target
		entry.t += dt
		local moving = model:GetAttribute("Moving") == true
		local speed = model:GetAttribute("Speed") or 0
		local t = entry.t
		-- Kołysanie przy chodzeniu, oddychanie w miejscu
		local bobY = if moving then math.abs(math.sin(t * speed * 0.9)) * 0.3 else math.sin(t * 2) * 0.07
		local tilt = if moving then math.sin(t * speed * 0.45) * math.rad(4) else 0
		local pivot = entry.current * CFrame.new(0, bobY, 0) * CFrame.Angles(0, 0, tilt)
		model:PivotTo(pivot)
		local mood = model:GetAttribute("Mood")
		for _, animated in entry.parts do
			local delta = animated.fn(t, mood)
			if animated.hinge then
				animated.part.CFrame = pivot * animated.hinge * delta * animated.hinge:Inverse() * animated.base
			else
				animated.part.CFrame = pivot * animated.base * delta
			end
		end
		-- Części widoczne tylko w pościgu (otwarte oczy) albo tylko poza nim (zamknięte)
		local alert = mood == "alert"
		if entry.alert ~= alert then
			entry.alert = alert
			for _, item in entry.alertParts do
				item.part.Transparency = if item.show == alert then 0 else 1
			end
		end
	end
end

function MonsterRenderer.Start()
	local rounds = Workspace:WaitForChild("Rounds")
	for _, descendant in rounds:GetDescendants() do
		track(descendant)
	end
	rounds.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then
			-- Atrybuty i części mogą dojść chwilę później niż sam model
			task.defer(track, descendant)
			task.delay(1, track, descendant)
		end
	end)
	RunService.RenderStepped:Connect(render)
end

return MonsterRenderer

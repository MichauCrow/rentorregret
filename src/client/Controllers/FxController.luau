-- Efekty rundy: start z podpowiedziami, znalezione monety, wpłata, złapanie (jumpscare można wyłączyć),
-- północ, zapłacony czynsz (konfetti), wskazówka duszka i ekran podsumowania.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Format"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local NightConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NightConfig"))
local ClientState = require(script.Parent.ClientState)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)
local UIKit = require(script.Parent.UIKit)

local FxController = {}

local C = UIKit.COLORS
local gui = nil
local summary = nil

-- Kreskówkowe "straszaki": duża buzia + napis, bez krwi
local SCARES = {
	neighbor = { face = "🤫", text = "CIIIIII-SZA!", color = Color3.fromRGB(150, 190, 255), message = "Cichy Sąsiad Cię usłyszał i odprowadził do łóżka!" },
	cat = { face = "🐱", text = "MRRRAU!", color = Color3.fromRGB(255, 210, 80), message = "Mruczek Cię przytulił i nie chce puścić!" },
	landlord = { face = "🔑", text = "CZYNSZ!!!", color = Color3.fromRGB(255, 150, 60), message = "Klucznik Cię złapał!" },
}

local function centerLabel(text: string, size: number, color: Color3, y: number): TextLabel
	local label = UIKit.label("Fx", {
		Size = UDim2.fromOffset(1000, size + 20),
		Position = UDim2.fromScale(0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = text,
		TextSize = size,
		TextColor3 = color,
		ZIndex = 20,
	})
	label.Parent = gui
	return label
end

local function fadeAndDestroy(instance: GuiObject, delay: number)
	task.delay(delay, function()
		if not instance.Parent then
			return
		end
		local props = if instance:IsA("TextLabel") then { TextTransparency = 1 } else { BackgroundTransparency = 1 }
		TweenService:Create(instance, TweenInfo.new(0.5), props):Play()
		local stroke = instance:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		task.wait(0.55)
		instance:Destroy()
	end)
end

-- Wyskakujący napis. Monety pokazujemy obok licznika kieszeni u góry (nie zasłaniają środka ekranu),
-- rzadkie większe napisy (low = true) nisko na środku.
local function popup(text: string, color: Color3, low: boolean?)
	local label = UIKit.label("Popup", {
		Size = UDim2.fromOffset(if low then 520 else 260, 50),
		Position = if low then UDim2.fromScale(0.5, 0.6) else UDim2.new(0.5, 300 + math.random(-20, 20), 0, 118),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = text,
		TextSize = if low then 34 else 28,
		TextColor3 = color,
		ZIndex = 15,
	})
	label.Parent = gui
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = label.Position - UDim2.fromOffset(0, 34) }):Play()
	fadeAndDestroy(label, 0.8)
end

local function shakeCamera(duration: number, strength: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < duration do
			local fade = 1 - (os.clock() - started) / duration
			camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * strength * fade), math.rad((math.random() - 0.5) * strength * fade), 0)
			task.wait()
		end
	end)
end

local function jumpscare(monster: string)
	local scare = SCARES[monster] or SCARES.landlord
	local profile = ClientState.profile
	local enabled = profile == nil or profile.settings.jumpscares ~= false
	SoundController.Play("Caught")
	if enabled then
		local flash = UIKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.15, ZIndex = 30 })
		flash.Parent = gui
		local face = UIKit.label("Face", {
			Size = UDim2.fromOffset(500, 500),
			Position = UDim2.fromScale(0.5, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = scare.face,
			TextScaled = true,
			ZIndex = 31,
		})
		local faceScale = UIKit.create("UIScale", { Scale = 0.2 })
		faceScale.Parent = face
		face.Parent = flash
		local shout = UIKit.label("Shout", {
			Size = UDim2.fromOffset(900, 90),
			Position = UDim2.fromScale(0.5, 0.82),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = scare.text,
			TextSize = 72,
			TextColor3 = scare.color,
			ZIndex = 31,
		})
		shout.Parent = flash
		TweenService:Create(faceScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		shakeCamera(0.6, 6)
		task.delay(1.4, function()
			TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(face, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(shout, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			task.wait(0.55)
			flash:Destroy()
		end)
	end
	local message = centerLabel(scare.message .. "\n👻 Jesteś teraz duszkiem.", 28, Color3.fromRGB(200, 230, 255), 0.3)
	fadeAndDestroy(message, if enabled then 4.5 else 3.5)
end

-- Start rundy: trzy obrazki zamiast ściany tekstu (zasady potworów uczą podpowiedzi na piętrach)
local INTRO_CARDS = {
	{ icon = "🔍", text = "Szukaj monet w meblach" },
	{ icon = "💰", text = "Wpłać je w BIURZE" },
	{ icon = "🕛", text = "Zdąż przed północą!" },
}

local function showIntro(data)
	local panel = UIKit.panel("Intro", UDim2.fromOffset(700, 300), UDim2.fromScale(0.5, 0.48), Vector2.new(0.5, 0.5))
	UIKit.label("Title", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 10), Text = string.format("🕛 Czynsz: %s 💰 do północy!", Format.Number(data.rent or 0)), TextSize = 32, TextColor3 = C.title }).Parent = panel
	local row = UIKit.create("Frame", { Size = UDim2.new(1, -40, 0, 150), Position = UDim2.fromOffset(20, 64), BackgroundTransparency = 1 }, {
		UIKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, card in INTRO_CARDS do
		local frame = UIKit.create("Frame", { Size = UDim2.fromOffset(196, 150), BackgroundColor3 = C.card, LayoutOrder = index }, { UIKit.corner(14), UIKit.border(C.stroke, 2) })
		UIKit.label("Icon", { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 8), Text = card.icon, TextScaled = true }).Parent = frame
		UIKit.label("Text", { Size = UDim2.new(1, -12, 0, 56), Position = UDim2.fromOffset(6, 90), Text = card.text, TextSize = 20 }).Parent = frame
		frame.Parent = row
	end
	row.Parent = panel
	local night = NightConfig.ById(data.night)
	UIKit.label("Night", { Size = UDim2.new(1, -40, 0, 44), Position = UDim2.fromOffset(20, 218), Text = night.icon .. " " .. night.name .. "\n" .. night.description, TextSize = 17, TextColor3 = Color3.fromRGB(255, 225, 150) }).Parent = panel
	local ok = UIKit.button("Ok", "RUSZAMY! 🔦", C.button, { Size = UDim2.fromOffset(200, 44), Position = UDim2.new(0.5, 0, 1, 18), AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 22 })
	ok.Activated:Connect(function()
		panel:Destroy()
	end)
	ok.Parent = panel
	panel.Parent = gui
	UIKit.popIn(panel)
	task.delay(7, function()
		if panel.Parent then
			panel:Destroy()
		end
	end)
end

-- Znacznik szybkiego komunikatu w świecie (np. "💰 Tutaj monety!" nad głową gracza, przez kilka sekund)
local function commsMarker(data)
	if typeof(data.position) ~= "Vector3" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = Workspace.Terrain
	attachment.WorldPosition = data.position
	local billboard = UIKit.create("BillboardGui", {
		Size = UDim2.fromOffset(240, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		Adornee = attachment,
		MaxDistance = 250,
	})
	local text = GameConfig.QUICK_CHAT[data.index] or ""
	UIKit.label("Text", { Size = UDim2.fromScale(1, 1), Text = text, TextScaled = true, TextColor3 = Color3.fromRGB(255, 220, 120) }).Parent = billboard
	billboard.Parent = gui.Parent -- BillboardGui musi być w PlayerGui (w ScreenGui się nie wyświetla)
	HUDController.Toast("📣 " .. tostring(data.by) .. ": " .. text, "info")
	task.delay(6, function()
		billboard:Destroy()
		attachment:Destroy()
	end)
end

local OUTCOMES = {
	escaped = { title = "🏃 UCIEKŁEŚ!", color = Color3.fromRGB(120, 255, 140) },
	paidStayed = { title = "✅ CZYNSZ ZAPŁACONY!", color = Color3.fromRGB(120, 255, 140) },
	caught = { title = "👻 ZŁAPANY!", color = Color3.fromRGB(180, 210, 255) },
}

local function showSummary(data)
	if summary then
		summary:Destroy()
	end
	local outcome = OUTCOMES[data.outcome] or OUTCOMES.caught
	local panel = UIKit.panel("Summary", UDim2.fromOffset(560, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.ZIndex = 25
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }).Parent = panel
	UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }).Parent = panel
	local lines = {
		{ outcome.title, 40, outcome.color },
		{ if data.rentPaid then "Czynsz zapłacony" .. (if data.time then " w " .. data.time else "") .. " 🎉" else "Czynsz niezapłacony 😬", 22, C.text },
		{ string.format("Drużyna wpłaciła: %s / %s 💰", Format.Number(data.teamDeposited), Format.Number(data.rent)), 22, C.text },
		{ string.format("Ty znalazłeś: %s 💰, wpłaciłeś: %s 💰", Format.Number(data.found), Format.Number(data.deposited)), 22, C.text },
		{ string.format("NAGRODA: +%s 💰", Format.Number(data.reward)), 34, C.title },
		{ if (data.closeCalls or 0) > 0 then string.format("😮 O włos: %d razy (+%d 💰)", data.closeCalls, data.closeCalls * GameConfig.CLOSE_CALL_BONUS) else "", 20, Color3.fromRGB(255, 200, 150) },
		{ "Za chwilę wracasz do holu...", 18, Color3.fromRGB(200, 200, 230) },
	}
	for index, line in lines do
		local label = UIKit.label("Line", { Size = UDim2.new(1, 0, 0, line[2] + 10), Text = line[1], TextSize = line[2], TextColor3 = line[3], LayoutOrder = index, ZIndex = 26 })
		label.Parent = panel
	end
	panel.Parent = gui
	UIKit.popIn(panel)
	summary = panel
	if data.outcome ~= "caught" then
		UIKit.confetti(gui, 50)
		SoundController.Play("Success")
	end
end

function FxController.Init()
	gui = UIKit.screenGui("Fx", 20)
end

function FxController.Start()
	ClientState.OnRoundEvent(function(kind, data)
		data = if type(data) == "table" then data else {}
		if kind == "start" then
			if summary then
				summary:Destroy()
				summary = nil
			end
			showIntro(data)
		elseif kind == "found" then
			if (data.amount or 0) > 0 then
				popup("+" .. data.amount .. " 💰", if data.big then C.title else Color3.fromRGB(255, 230, 120))
				SoundController.Play("Coins")
			else
				popup("Pusto...", Color3.fromRGB(190, 190, 210))
			end
		elseif kind == "deposit" then
			popup("Wpłacono " .. (data.amount or 0) .. " 💰", C.good)
			SoundController.Play("Coins", 1.2)
		elseif kind == "alert" then
			HUDController.Alert(data.text or "", data.kind)
			if data.kind == "bad" then
				SoundController.Play("Warning")
			end
		elseif kind == "caught" then
			jumpscare(data.monster)
		elseif kind == "midnight" then
			SoundController.Play("Midnight")
			local label = centerLabel("🕛 PÓŁNOC!", 80, Color3.fromRGB(255, 150, 60), 0.35)
			shakeCamera(0.8, 3)
			fadeAndDestroy(label, 2.5)
		elseif kind == "paid" then
			UIKit.confetti(gui, 70)
			SoundController.Play("RentPaid")
			local label = centerLabel("🎉 CZYNSZ ZAPŁACONY!", 56, C.good, 0.35)
			fadeAndDestroy(label, 2.5)
		elseif kind == "finale" then
			SoundController.Play("Warning")
			local label = centerLabel("⚠️ 23:55! Kamienica się budzi!", 52, Color3.fromRGB(255, 110, 110), 0.33)
			shakeCamera(0.6, 2)
			fadeAndDestroy(label, 2.5)
		elseif kind == "closecall" then
			popup("😮 O WŁOS! +" .. (data.bonus or 0) .. " 💰", Color3.fromRGB(255, 200, 150), true)
			SoundController.Play("Success", 1.2)
		elseif kind == "breathOk" then
			popup("😮‍💨 Uff! Udało się! +" .. (data.bonus or 0) .. " 💰", C.good, true)
			SoundController.Play("Success")
		elseif kind == "comms" then
			commsMarker(data)
		elseif kind == "ping" then
			HUDController.Toast("👻 " .. tostring(data.by) .. " wskazuje: " .. tostring(data.label) .. " (świeci na niebiesko)", "info")
		elseif kind == "end" then
			showSummary(data)
		end
	end)
	ClientState.OnRound(function(round)
		if round == nil and summary then
			local panel = summary
			summary = nil
			task.delay(0.5, function()
				panel:Destroy()
			end)
		end
	end)
end

return FxController

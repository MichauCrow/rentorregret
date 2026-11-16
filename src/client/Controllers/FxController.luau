-- Efekty rundy: start z podpowiedziami, znalezione monety, wpłata, złapanie (jumpscare można wyłączyć),
-- północ, zapłacony czynsz (konfetti), wskazówka duszka i ekran podsumowania.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Format"))
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

local TIPS = {
	"🔍 Przeszukuj meble (przytrzymaj E) i zbieraj monety.",
	"💰 Zanoś monety do skrzynki Klucznika w BIURZE na parterze.",
	"🤫 Na 1. piętrze mieszka Cichy Sąsiad: słyszy bieganie. Idź powoli!",
	"🔦 Na 2. piętrze śpi Mruczek: idzie za światłem latarki. Gaś ją przy nim!",
	"🚪 W tarapatach chowaj się w szafie.",
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

local function popup(text: string, color: Color3)
	local label = UIKit.label("Popup", {
		Size = UDim2.fromOffset(300, 50),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.1, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = text,
		TextSize = 34,
		TextColor3 = color,
		ZIndex = 15,
	})
	label.Parent = gui
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = label.Position - UDim2.fromScale(0, 0.12) }):Play()
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

local function showIntro(data)
	local lines = { string.format("🕗 Masz czas do północy, żeby uzbierać %s 💰 czynszu!", Format.Number(data.rent)) }
	local profile = ClientState.profile
	if not profile or not profile.tutorialDone then
		for _, tip in TIPS do
			table.insert(lines, tip)
		end
	else
		table.insert(lines, TIPS[math.random(1, #TIPS)])
	end
	local panel = UIKit.panel("Intro", UDim2.fromOffset(720, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }).Parent = panel
	UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }).Parent = panel
	local title = UIKit.label("Title", { Size = UDim2.new(1, 0, 0, 44), Text = "🏚️ KAMIENICA NOCĄ", TextSize = 34, TextColor3 = C.title, LayoutOrder = 0 })
	title.Parent = panel
	for index, line in lines do
		local label = UIKit.label("Line", { Size = UDim2.new(1, 0, 0, 30), Text = line, TextSize = 21, LayoutOrder = index, TextXAlignment = Enum.TextXAlignment.Left })
		label.Parent = panel
	end
	local ok = UIKit.button("Ok", "RUSZAMY! 🔦", C.button, { Size = UDim2.fromOffset(220, 52), LayoutOrder = #lines + 1, TextSize = 24 })
	ok.Activated:Connect(function()
		panel:Destroy()
	end)
	ok.Parent = panel
	panel.Parent = gui
	UIKit.popIn(panel)
	task.delay(if profile and profile.tutorialDone then 6 else 14, function()
		if panel.Parent then
			panel:Destroy()
		end
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

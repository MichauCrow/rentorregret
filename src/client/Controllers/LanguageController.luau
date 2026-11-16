-- Język gry: polski (teksty w kodzie) albo angielski (tłumaczone przy wyświetlaniu przez moduł Lang).
-- Język wybieramy z ustawień Roblox gracza (pl = polski, reszta świata = angielski), przycisk PL/EN go zmienia.
-- Śledzimy teksty w interfejsie, na szyldach w świecie i w podpowiedziach (ProximityPrompt):
-- przy każdej zmianie tekstu przez grę zapamiętujemy oryginał i pokazujemy wersję w wybranym języku.
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Lang"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local LanguageController = {}

local TEXT_PROPS = { "Text" }
local PROMPT_PROPS = { "ActionText", "ObjectText" }

local language = "pl"
local tracked = setmetatable({}, { __mode = "k" }) -- [instancja] = { [właściwość] = { original, shown } }
local toggleButton = nil

local function render(instance: Instance, prop: string)
	local entry = tracked[instance][prop]
	local wanted = if language == "en" then Lang.ToEnglish(entry.original) else entry.original
	entry.shown = wanted
	if (instance :: any)[prop] ~= wanted then
		(instance :: any)[prop] = wanted
	end
end

local function track(instance: Instance)
	if tracked[instance] or instance:GetAttribute("NoTranslate") then
		return
	end
	local props = nil
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		props = TEXT_PROPS
	elseif instance:IsA("ProximityPrompt") then
		props = PROMPT_PROPS
	else
		return
	end
	tracked[instance] = {}
	for _, prop in props do
		tracked[instance][prop] = { original = (instance :: any)[prop], shown = nil }
		render(instance, prop)
		instance:GetPropertyChangedSignal(prop):Connect(function()
			local entry = tracked[instance] and tracked[instance][prop]
			if not entry then
				return
			end
			local current = (instance :: any)[prop]
			if current ~= entry.shown then
				-- Gra ustawiła nowy tekst: to jest nowy oryginał
				entry.original = current
				render(instance, prop)
			end
		end)
	end
end

local function watch(root: Instance)
	for _, descendant in root:GetDescendants() do
		track(descendant)
	end
	root.DescendantAdded:Connect(track)
end

local function updateButton()
	if toggleButton then
		toggleButton.Text = if language == "en" then "EN" else "PL"
	end
end

function LanguageController.Get(): string
	return language
end

function LanguageController.Set(newLanguage: string)
	if newLanguage ~= "pl" and newLanguage ~= "en" then
		return
	end
	language = newLanguage
	for instance, props in tracked do
		if instance.Parent then
			for prop in props do
				render(instance, prop)
			end
		end
	end
	updateButton()
end

local function detectLanguage(): string
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if not ok or type(locale) ~= "string" or locale == "" then
		ok, locale = pcall(function()
			return LocalizationService.SystemLocaleId
		end)
	end
	if ok and type(locale) == "string" and locale:lower():sub(1, 2) == "pl" then
		return "pl"
	end
	return "en"
end

function LanguageController.Init()
	language = detectLanguage()
	watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	watch(Workspace)

	-- Przycisk obok dźwięku (ta sama skala i układ co HUD)
	local gui = UIKit.screenGui("LanguageUI", 1, "hud")
	toggleButton = UIKit.button("Language", "PL", UIKit.COLORS.panel, {
		Size = UDim2.fromOffset(56, 44),
		Position = UDim2.fromOffset(216, 128),
		TextSize = 20,
	})
	toggleButton:SetAttribute("NoTranslate", true)
	toggleButton.Activated:Connect(function()
		LanguageController.Set(if language == "en" then "pl" else "en")
	end)
	toggleButton.Parent = gui
	updateButton()
end

return LanguageController

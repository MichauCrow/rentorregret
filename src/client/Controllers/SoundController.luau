-- Dźwięki interfejsu i muzyka w tle. Przycisk 🔊 przełącza: wszystko / bez muzyki / cisza.
-- Dźwięki są tylko u gracza (2D), niczego nie zmieniają w grze.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AssetsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetsConfig"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local SoundController = {}

local MODES = {
	{ icon = "🔊", music = true, sfx = true },
	{ icon = "🎵", music = false, sfx = true },
	{ icon = "🔇", music = false, sfx = false },
}
local MIN_REPEAT = { Warning = 2, Coins = 0.15, UIClick = 0.05 } -- nie powtarzaj szybciej niż (s)

local modeIndex = 1
local lastPlayed = {}
local music = nil
local musicIndex = 1
local toggleButton = nil

-- Czy efekty dźwiękowe są włączone (używa też CleanFxController)
function SoundController.SfxEnabled(): boolean
	return MODES[modeIndex].sfx
end

-- speed: opcjonalna wysokość dźwięku (np. rosnąca przy kolejnych gwiazdkach)
function SoundController.Play(key: string, speed: number?)
	if not MODES[modeIndex].sfx then
		return
	end
	local soundId = AssetsConfig.Sounds[key]
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	local now = os.clock()
	if lastPlayed[key] and now - lastPlayed[key] < (MIN_REPEAT[key] or 0) then
		return
	end
	lastPlayed[key] = now
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = AssetsConfig.Volumes[key] or 0.5
	sound.PlaybackSpeed = speed or 1
	sound.Parent = SoundService
	sound:Play()
	local maxLength = AssetsConfig.SoundMaxLength[key]
	if maxLength then
		task.delay(maxLength, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
			end
		end)
	end
	Debris:AddItem(sound, (maxLength or 6) + 1)
end

local function startMusic()
	if music or #AssetsConfig.Music == 0 then
		return
	end
	music = Instance.new("Sound")
	music.Name = "BackgroundMusic"
	music.Volume = AssetsConfig.Volumes.Music or 0.2
	music.SoundId = AssetsConfig.Music[musicIndex]
	music.Parent = SoundService
	music.Ended:Connect(function()
		musicIndex = musicIndex % #AssetsConfig.Music + 1
		music.SoundId = AssetsConfig.Music[musicIndex]
		music:Play()
	end)
	music:Play()
end

local function applyMode()
	local mode = MODES[modeIndex]
	if toggleButton then
		toggleButton.Text = mode.icon
	end
	if mode.music then
		startMusic()
		if music and not music.IsPlaying then
			music:Resume()
		end
	elseif music then
		music:Pause()
	end
end

-- Reakcje na komunikaty serwera (rodzaj i treść toastu)
function SoundController.OnNotify(text: any, kind: any)
	if type(text) ~= "string" then
		return
	end
	if text:find("Czynsz zapłacony", 1, true) or text:find("Udało się w dogrywce", 1, true) then
		SoundController.Play("RentPaid")
	elseif text:find("🏅", 1, true) or text:find("🎉", 1, true) or text:find("⭐ Zlecenie wykonane", 1, true) then
		SoundController.Play("Success")
	elseif kind == "warn" or kind == "bad" then
		SoundController.Play("Warning")
	end
end

function SoundController.Init()
	UIKit.SetPressSound(function()
		SoundController.Play("UIClick")
	end)

	-- Mały przycisk obok kluczy (ten sam układ i skala co HUD)
	local gui = UIKit.screenGui("SoundUI", 1, "hud")
	toggleButton = UIKit.button("Sound", MODES[1].icon, UIKit.COLORS.panel, {
		Size = UDim2.fromOffset(48, 44),
		Position = UDim2.fromOffset(160, 128),
		TextSize = 24,
	})
	toggleButton.Activated:Connect(function()
		modeIndex = modeIndex % #MODES + 1
		applyMode()
	end)
	toggleButton.Parent = gui
	applyMode()
end

return SoundController

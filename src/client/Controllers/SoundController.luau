-- Dźwięki efektów i muzyka (tylko w holu; w kamienicy cisza buduje klimat).
-- Tryb dźwięku jest w ustawieniach gracza: 1 = wszystko, 2 = bez muzyki, 3 = cisza.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AssetsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetsConfig"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local SoundController = {}

local MIN_REPEAT = { Warning = 2, Coins = 0.15, UIClick = 0.05 } -- nie powtarzaj szybciej niż (s)

local lastPlayed = {}
local music = nil
local musicIndex = 1
local inRound = false

local function mode(): number
	local profile = ClientState.profile
	return if profile then profile.settings.sound or 1 else 1
end

function SoundController.SfxEnabled(): boolean
	return mode() < 3
end

-- speed: opcjonalna wysokość dźwięku
function SoundController.Play(key: string, speed: number?)
	if not SoundController.SfxEnabled() then
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

local function updateMusic()
	local wanted = mode() == 1 and not inRound and #AssetsConfig.Music > 0
	if wanted and not music then
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
	elseif music then
		if wanted and not music.IsPlaying then
			music:Resume()
		elseif not wanted and music.IsPlaying then
			music:Pause()
		end
	end
end

function SoundController.Init()
	UIKit.SetPressSound(function()
		SoundController.Play("UIClick")
	end)
end

function SoundController.Start()
	ClientState.OnProfile(updateMusic)
	ClientState.OnRound(function(round)
		inRound = round ~= nil
		updateMusic()
	end)
end

return SoundController

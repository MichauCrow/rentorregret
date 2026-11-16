-- Dźwięki efektów i muzyka (tylko w holu; w kamienicy cisza buduje klimat).
-- Tryb dźwięku jest w ustawieniach gracza: 1 = wszystko, 2 = bez muzyki, 3 = cisza.
local ContentProvider = game:GetService("ContentProvider")
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

-- Dźwięk przypięty do części (3D: cichnie z odległością). Zwraca Sound albo nil, gdy brak ID.
function SoundController.Attach(parent: Instance, key: string, looped: boolean, maxDistance: number?): Sound?
	local soundId = AssetsConfig.Sounds[key]
	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = soundId
	sound.Volume = if SoundController.SfxEnabled() then AssetsConfig.Volumes[key] or 0.5 else 0
	sound.PlaybackSpeed = AssetsConfig.Pitch[key] or 1
	sound.Looped = looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = maxDistance or 50
	sound:SetAttribute("BaseVolume", AssetsConfig.Volumes[key] or 0.5)
	sound.Parent = parent
	sound:Play()
	return sound
end

-- Tylko w Studio: raport w oknie Output, które dźwięki się wczytują
function SoundController.CheckAll()
	local list = {}
	for key, id in AssetsConfig.Sounds do
		if id ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = id
			list[key] = sound
		end
	end
	for _, id in AssetsConfig.Music do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		list["Muzyka " .. id] = sound
	end
	local results = {}
	for key, sound in list do
		ContentProvider:PreloadAsync({ sound }, function(_, status)
			results[key] = status
		end)
	end
	local lines = { "[Dźwięki] raport:" }
	for key, id in AssetsConfig.Sounds do
		if id == "" then
			table.insert(lines, "  ⬜ " .. key .. ": brak ID (dodaj w AssetsConfig)")
		else
			local status = results[key]
			local ok = status == Enum.AssetFetchStatus.Success
			table.insert(lines, (if ok then "  ✅ " else "  ❌ ") .. key .. (if ok then "" else ": nie wczytuje się (" .. tostring(status) .. ")"))
		end
	end
	print(table.concat(lines, "\n"))
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

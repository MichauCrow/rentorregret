-- Stan po stronie klienta: zapisany profil (monety, ulepszenia, ustawienia) i bieżąca runda (albo nil w holu).
-- Kontrolery subskrybują zmiany przez OnProfile / OnRound i zdarzenia rundy przez OnRoundEvent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientState = {}

ClientState.profile = nil
ClientState.round = nil

local profileListeners = {}
local roundListeners = {}
local eventListeners = {}
local notifyListeners = {}

local function fire(list, ...)
	for _, callback in list do
		task.spawn(callback, ...)
	end
end

function ClientState.OnProfile(callback)
	table.insert(profileListeners, callback)
	if ClientState.profile then
		task.spawn(callback, ClientState.profile)
	end
end

function ClientState.OnRound(callback)
	table.insert(roundListeners, callback)
	task.spawn(callback, ClientState.round)
end

function ClientState.OnRoundEvent(callback)
	table.insert(eventListeners, callback)
end

function ClientState.OnNotify(callback)
	table.insert(notifyListeners, callback)
end

function ClientState.InRound(): boolean
	return ClientState.round ~= nil
end

function ClientState.Remote(name: string)
	return ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild(name)
end

function ClientState.SetProfile(profile)
	ClientState.profile = profile
	fire(profileListeners, profile)
end

function ClientState.Init()
	ClientState.Remote("StateUpdate").OnClientEvent:Connect(function(profile)
		if type(profile) == "table" then
			ClientState.SetProfile(profile)
		end
	end)
	ClientState.Remote("RoundState").OnClientEvent:Connect(function(round)
		ClientState.round = if type(round) == "table" then round else nil
		fire(roundListeners, ClientState.round)
	end)
	ClientState.Remote("RoundEvent").OnClientEvent:Connect(function(kind, data)
		fire(eventListeners, kind, data)
	end)
	ClientState.Remote("Notify").OnClientEvent:Connect(function(text, kind)
		fire(notifyListeners, text, kind)
	end)
end

function ClientState.Start()
	task.spawn(function()
		local ok, profile = pcall(function()
			return ClientState.Remote("GetState"):InvokeServer()
		end)
		if ok and type(profile) == "table" then
			ClientState.SetProfile(profile)
		end
	end)
end

return ClientState

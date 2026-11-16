-- Tworzy wszystkie Remote'y, pilnuje limitu zapytań i daje walidatory argumentów.
-- Każdy handler od klienta MUSI przejść przez OnServerEvent / OnServerInvoke z tego modułu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)

local RemoteService = {}

local events = {}
local functions = {}
local buckets = {} -- [player][remoteName] = { tokens, last }

-- Token bucket: maksymalnie `rate` zapytań na sekundę, z krótkim zapasem
local function allow(player: Player, name: string, rate: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { tokens = rate, last = now }
		playerBuckets[name] = bucket
	end
	bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function getOrCreate(folder: Folder, className: string, name: string)
	local remote = folder:FindFirstChild(name)
	if not remote or remote.ClassName ~= className then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

function RemoteService.Init()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local folder = shared:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end
	for _, name in RemoteNames.Events do
		events[name] = getOrCreate(folder, "RemoteEvent", name)
	end
	for _, name in RemoteNames.Functions do
		functions[name] = getOrCreate(folder, "RemoteFunction", name)
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function RemoteService.Event(name: string): RemoteEvent
	local remote = events[name]
	assert(remote, "Nieznany RemoteEvent: " .. tostring(name))
	return remote
end

function RemoteService.Function(name: string): RemoteFunction
	local remote = functions[name]
	assert(remote, "Nieznana RemoteFunction: " .. tostring(name))
	return remote
end

-- Handler dostaje (player, ...). Zapytania ponad limit są po cichu odrzucane.
function RemoteService.OnServerEvent(name: string, ratePerSecond: number, handler)
	RemoteService.Event(name).OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, ratePerSecond) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn("[RemoteService] Błąd w " .. name .. ": " .. tostring(err))
		end
	end)
end

function RemoteService.OnServerInvoke(name: string, ratePerSecond: number, handler)
	RemoteService.Function(name).OnServerInvoke = function(player, ...)
		if not allow(player, name, ratePerSecond) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn("[RemoteService] Błąd w " .. name .. ": " .. tostring(result))
			return nil
		end
		return result
	end
end

-- Walidatory danych od klienta
function RemoteService.IsInteger(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and math.floor(value) == value and value >= min and value <= max
end

function RemoteService.IsString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

function RemoteService.IsOneOf(value: any, allowed: { any }): boolean
	for _, item in allowed do
		if value == item then
			return true
		end
	end
	return false
end

return RemoteService

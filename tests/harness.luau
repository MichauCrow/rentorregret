-- Uruchamia moduły gry w Lune: emuluje `script`, `game:GetService` i `require` po ścieżkach Rojo.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local H = {}
H.root = process.cwd .. "src" -- uruchamiaj z głównego folderu repozytorium
H.mounts = { ReplicatedStorage = { Shared = "shared" }, ServerScriptService = "server" }
H.services = { CollectionService = { AddTag = function() end, GetTagged = function() return {} end } } -- [nazwa] = atrapa usługi
H.overrides = {} -- [ścieżka pliku bez .luau] = gotowa wartość modułu

local cache = {}
local proxyOf

local function resolve(path: string): string?
	for _, candidate in { path .. ".luau", path .. ".server.luau", path .. ".client.luau", path .. "/init.luau" } do
		if fs.isFile(candidate) then
			return candidate
		end
	end
	return nil
end

local function loadModule(path: string)
	if H.overrides[path] ~= nil then
		return H.overrides[path]
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = resolve(path)
	assert(file, "brak modułu: " .. path)
	local env = {}
	for k, v in H.env do
		env[k] = v
	end
	for _, k in { "print", "warn", "error", "assert", "pcall", "xpcall", "type", "typeof", "tostring", "tonumber", "pairs", "ipairs", "next", "select", "setmetatable", "getmetatable", "rawget", "rawset", "rawequal", "unpack", "math", "string", "table", "os", "task", "coroutine", "utf8", "bit32", "buffer" } do
		if env[k] == nil then
			env[k] = (getfenv() :: any)[k]
		end
	end
	env.script = proxyOf(path)
	local fn = luau.load(luau.compile(fs.readFile(file)), { debugName = file, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

-- Proxy ścieżki: indeksowanie / WaitForChild / FindFirstChild schodzą w głąb, .Parent idzie w górę
function proxyOf(path: string)
	local p = {}
	return setmetatable(p, {
		__index = function(_, key)
			if key == "Parent" then
				return proxyOf((path:match("^(.*)/[^/]+$")) or path)
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return proxyOf(path .. "/" .. name)
				end
			elseif key == "Name" then
				return path:match("([^/]+)$")
			end
			return proxyOf(path .. "/" .. key)
		end,
		__tostring = function()
			return "Proxy(" .. path .. ")"
		end,
		__path = path,
	})
end

local function mountProxy(service: string)
	local mount = H.mounts[service]
	if type(mount) == "string" then
		return proxyOf(H.root .. "/" .. mount)
	end
	local t = {}
	for child, dir in mount do
		t[child] = proxyOf(H.root .. "/" .. dir)
	end
	t.WaitForChild = function(self, name)
		return self[name]
	end
	t.FindFirstChild = t.WaitForChild
	return t
end

local game = {}
function game:GetService(name: string)
	if H.services[name] then
		return H.services[name]
	end
	if H.mounts[name] then
		return mountProxy(name)
	end
	error("brak usługi w harnessie: " .. name)
end

H.env = {
	game = game,
	require = function(target)
		local mt = getmetatable(target)
		assert(mt and mt.__path, "require nie-proxy: " .. tostring(target))
		return loadModule(mt.__path)
	end,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Enum = roblox.Enum,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberRange = roblox.NumberRange,
	Random = roblox.Random or {
		new = function(seed)
			local state = (seed or os.clock() * 1e6) % 2147483647
			if state <= 0 then state += 2147483646 end
			local function nxt()
				state = (state * 16807) % 2147483647
				return state / 2147483647
			end
			return {
				NextNumber = function(_, a, b)
					local r = nxt()
					if a then return a + (b - a) * r end
					return r
				end,
				NextInteger = function(_, a, b)
					return a + math.floor(nxt() * (b - a + 1))
				end,
			}
		end,
	},
	TweenInfo = { new = function(...) return { ... } end },
	warn = function(...) print("WARN", ...) end,
	task = require("@lune/task"),
	typeof = roblox.typeof or typeof,
}

H.load = loadModule
H.roblox = roblox
return H

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
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
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

-- Sygnał jak RBXScriptSignal (Connect / Once / Fire)
function H.signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local connection = { Connected = true }
		function connection:Disconnect()
			self.Connected = false
		end
		table.insert(self.handlers, { fn = fn, connection = connection })
		return connection
	end
	function s:Once(fn)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end
	function s:Fire(...)
		for _, handler in table.clone(self.handlers) do
			if handler.connection.Connected then
				handler.fn(...)
			end
		end
	end
	return s
end

-- Lune nie ma zdarzeń ani metod silnika na instancjach: dokładamy atrapy (zdarzenia to sygnały H.signal,
-- które test może sam odpalić, np. H.event(button, "Activated"):Fire()).
local signals = {}
function H.event(instance, name: string)
	local perInstance = signals[instance]
	if not perInstance then
		perInstance = {}
		signals[instance] = perInstance
	end
	if not perInstance[name] then
		perInstance[name] = H.signal()
	end
	return perInstance[name]
end

local engineInstalled = false
function H.installEngine()
	if engineInstalled then
		return
	end
	engineInstalled = true
	local EVENTS = {
		Instance = { "Changed", "AncestryChanged", "DescendantAdded", "DescendantRemoving", "ChildAdded", "ChildRemoved", "Destroying" },
		GuiObject = { "MouseEnter", "MouseLeave", "InputBegan", "InputEnded" },
		GuiButton = { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click" },
		Sound = { "Ended", "Played" },
		ProximityPrompt = { "Triggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
		BindableEvent = { "Event" },
	}
	for className, names in EVENTS do
		for _, name in names do
			roblox.implementProperty(className, name, function(instance)
				return H.event(instance, name)
			end)
		end
	end
	roblox.implementMethod("Instance", "WaitForChild", function(self, name)
		return self:FindFirstChild(name)
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, property)
		return H.event(self, "Changed:" .. property)
	end)
	roblox.implementMethod("BindableEvent", "Fire", function(self, ...)
		H.event(self, "Event"):Fire(...)
	end)
	for _, method in { "Play", "Pause", "Resume", "Stop" } do
		roblox.implementMethod("Sound", method, function() end)
	end
	local function parts(model)
		local list = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(list, descendant)
			end
		end
		return list
	end
	roblox.implementMethod("Model", "PivotTo", function(model, target)
		local primary = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or parts(model)[1]
		if not primary then
			return
		end
		local delta = target * primary.CFrame:Inverse()
		for _, part in parts(model) do
			part.CFrame = delta * part.CFrame
		end
	end)
	roblox.implementMethod("Model", "GetPivot", function(model)
		local primary = model.PrimaryPart or parts(model)[1]
		return if primary then primary.CFrame else roblox.CFrame.new()
	end)
	-- TweenService: zmiana stosowana od razu
	H.services.TweenService = H.services.TweenService or {
		Create = function(_, instance, _, props)
			local completed = H.signal()
			return {
				Completed = completed,
				Play = function()
					for key, value in props do
						instance[key] = value
					end
					completed:Fire()
				end,
			}
		end,
	}
	H.services.Debris = H.services.Debris or { AddItem = function() end }
	H.env.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
end

return H

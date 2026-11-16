-- Buduje plik gry (.rbxl) do otwarcia w Roblox Studio, bez Rojo:
--   lune run tools/build_place
-- Bierze place/RentOrRegret.rbxl (oświetlenie, Workspace, ustawienia czatu), usuwa stare skrypty
-- i wstawia kod z src/ w te same miejsca co default.project.json.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.cwd
local SOURCE = ROOT .. "place/RentOrRegret.rbxl"
local OUTPUT = ROOT .. "place/RentOrRegret_Polnoc.rbxl"

local game = roblox.deserializePlace(fs.readFile(SOURCE))
local counts = { Script = 0, LocalScript = 0, ModuleScript = 0, Folder = 0 }

local function scriptFrom(className: string, name: string, path: string)
	local instance = roblox.Instance.new(className)
	instance.Name = name
	instance.Source = fs.readFile(path)
	counts[className] += 1
	return instance
end

-- Folder z plikami -> instancje (zasady jak w Rojo)
local function build(dir: string, name: string)
	local container
	if fs.isFile(dir .. "/init.luau") then
		container = scriptFrom("ModuleScript", name, dir .. "/init.luau")
	else
		container = roblox.Instance.new("Folder")
		container.Name = name
		counts.Folder += 1
	end
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			build(path, entry).Parent = container
		elseif entry ~= "init.luau" then
			local base = entry:match("^(.*)%.server%.luau$")
			if base then
				scriptFrom("Script", base, path).Parent = container
			else
				base = entry:match("^(.*)%.client%.luau$")
				if base then
					scriptFrom("LocalScript", base, path).Parent = container
				else
					base = entry:match("^(.*)%.luau$")
					if base then
						scriptFrom("ModuleScript", base, path).Parent = container
					end
				end
			end
		end
	end
	return container
end

-- Zawartość folderu wstawiana prosto do usługi (ServerScriptService, StarterPlayerScripts)
local function fill(target, dir: string)
	for _, child in target:GetChildren() do
		child:Destroy()
	end
	local built = build(dir, "temp")
	for _, child in built:GetChildren() do
		child.Parent = target
	end
	counts.Folder -= 1
end

local replicated = game:GetService("ReplicatedStorage")
local oldShared = replicated:FindFirstChild("Shared")
if oldShared then
	oldShared:Destroy()
end
build(ROOT .. "src/shared", "Shared").Parent = replicated

fill(game:GetService("ServerScriptService"), ROOT .. "src/server")

local starterPlayer = game:GetService("StarterPlayer")
local playerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not playerScripts then
	playerScripts = roblox.Instance.new("StarterPlayerScripts")
	playerScripts.Parent = starterPlayer
end
fill(playerScripts, ROOT .. "src/client")

fs.writeFile(OUTPUT, roblox.serializePlace(game))
print(("zapisano %s: %d Script, %d LocalScript, %d ModuleScript, %d folderów"):format(OUTPUT, counts.Script, counts.LocalScript, counts.ModuleScript, counts.Folder))

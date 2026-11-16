-- Eksportuje świat gry (hol, kamienicę, potwory) do plików JSON dla podglądu 3D (render.mjs).
-- Uruchamiaj z głównego folderu repozytorium: lune run tools/preview/export_world
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local H = require("../../tests/harness")
local roblox = H.roblox
local I, V3, CF = roblox.Instance, roblox.Vector3, roblox.CFrame

H.installEngine()
local OUT = process.cwd .. "tools/preview/out"
fs.writeDir(OUT)

local function color(c)
	return { c.R, c.G, c.B }
end

local function textOf(gui)
	local label = gui:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		return nil
	end
	return {
		text = label.Text,
		color = color(label.TextColor3),
		bg = if label.BackgroundTransparency < 1 then color(label.BackgroundColor3) else nil,
	}
end

local function exportParts(root)
	local list = {}
	local candidates = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(candidates, root)
	end
	for _, part in candidates do
		if part:IsA("BasePart") then
			local entry = {
				n = part.Name,
				c = part.ClassName,
				s = { part.Size.X, part.Size.Y, part.Size.Z },
				cf = { part.CFrame:GetComponents() },
				col = color(part.Color),
				m = part.Material.Name,
				t = part.Transparency,
				collide = part.CanCollide,
				alert = part:GetAttribute("Alert"),
				sh = if part.ClassName == "Part" then part.Shape.Name else "Block",
				lights = {},
				signs = {},
				boards = {},
			}
			for _, child in part:GetChildren() do
				if child:IsA("SpecialMesh") then
					entry.mesh = { type = child.MeshType.Name, scale = { child.Scale.X, child.Scale.Y, child.Scale.Z } }
				elseif child:IsA("PointLight") or child:IsA("SpotLight") or child:IsA("SurfaceLight") then
					table.insert(entry.lights, {
						kind = child.ClassName,
						color = color(child.Color),
						brightness = child.Brightness,
						range = child.Range,
						face = if child:IsA("PointLight") then nil else child.Face.Name,
						angle = if child:IsA("PointLight") then nil else child.Angle,
					})
				elseif child:IsA("SurfaceGui") then
					local text = textOf(child)
					if text then
						text.face = child.Face.Name
						table.insert(entry.signs, text)
					end
				elseif child:IsA("Decal") then
					entry.decal = child.Face.Name
				elseif child:IsA("BillboardGui") then
					local text = textOf(child)
					if text then
						text.offset = child.StudsOffset.Y
						table.insert(entry.boards, text)
					end
				end
			end
			table.insert(list, entry)
		end
	end
	-- Napisy nad modelami (BillboardGui w modelu z Adornee)
	for _, gui in root:GetDescendants() do
		if gui:IsA("BillboardGui") and gui.Adornee and not gui.Parent:IsA("BasePart") then
			local text = textOf(gui)
			if text and text.text ~= "" then
				for _, entry in list do
					if entry.n == gui.Adornee.Name then
						text.offset = gui.StudsOffset.Y
						table.insert(entry.boards, text)
						break
					end
				end
			end
		end
	end
	return list
end

local function save(name: string, data)
	fs.writeFile(OUT .. "/" .. name .. ".json", serde.encode("json", data))
	print(("%-10s %d części"):format(name, #data.parts))
end

-- Potwory i Pan Klucznik (przód = -Z, stopy w zerze)
local MonsterModels = H.load(H.root .. "/server/World/MonsterModels")
local LandlordBuilder = H.load(H.root .. "/server/World/LandlordBuilder")
for id, build in { neighbor = MonsterModels.Neighbor, cat = MonsterModels.Cat, landlord = MonsterModels.Landlord } do
	save(id, { parts = exportParts(build()) })
end
local keymanFolder = I.new("Folder")
save("keyman", { parts = exportParts(LandlordBuilder.Build(CF.new(), "🙂", keymanFolder)) })

-- Hol
local workspace = I.new("Folder")
workspace.Name = "Workspace"
local baseplate = I.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = V3.new(2048, 16, 2048)
baseplate.CFrame = CF.new(0, -8, 0)
baseplate.Parent = workspace
local spawn = I.new("SpawnLocation")
spawn.Parent = workspace
H.services.Workspace = workspace
local LobbyBuilder = H.load(H.root .. "/server/World/LobbyBuilder")
local lobby = LobbyBuilder.Build()
save("lobby", { parts = exportParts(workspace), spawn = { lobby.spawnCFrame:GetComponents() } })

-- Kamienica z potworami na miejscach startowych (dla skali)
local BuildingBuilder = H.load(H.root .. "/server/World/BuildingBuilder")
local parent = I.new("Folder")
local origin = V3.new(0, 0.5, 0)
local building = BuildingBuilder.Build(origin, parent, tonumber(process.args[1]) or 42)
local neighbor = MonsterModels.Neighbor()
neighbor:PivotTo(CF.lookAt(building.neighborStart, building.neighborStart + V3.new(-1, 0, 0)))
neighbor.Parent = building.model
local cat = MonsterModels.Cat()
cat:PivotTo(CF.lookAt(building.catBed, building.catBed + V3.new(0, 0, -1)))
cat.Parent = building.model
local wardrobes = {}
for _, wardrobe in building.wardrobes do
	table.insert(wardrobes, { inside = { wardrobe.inside:GetComponents() }, outside = { wardrobe.outside:GetComponents() }, floor = wardrobe.floor })
end
save("building", {
	parts = exportParts(building.model),
	spawn = { building.spawn:GetComponents() },
	floorY = { building.floorY[0], building.floorY[1], building.floorY[2] },
	locked = { room = building.locked.room, floor = building.locked.floor },
	wardrobes = wardrobes,
	exit = { min = { building.exitMin.X, building.exitMin.Y, building.exitMin.Z }, max = { building.exitMax.X, building.exitMax.Y, building.exitMax.Z } },
})

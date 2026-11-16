local H = require("./harness")
local roblox = H.roblox
H.overrides[H.root .. "/server/World/LandlordBuilder"] = {
	Build = function(cframe, _, parent)
		local m = roblox.Instance.new("Model")
		m.Name = "PanKlucznik"
		m.Parent = parent
		return m
	end,
}
local BuildingBuilder = H.load(H.root .. "/server/World/BuildingBuilder")
local parent = roblox.Instance.new("Folder")
local origin = roblox.Vector3.new(100, 0.5, 400)
local b = BuildingBuilder.Build(origin, parent, 42)

print("spots", #b.spots, "wardrobes", #b.wardrobes, "rooms", #b.rooms, "locked room", b.locked.room, "floor", b.locked.floor)
local labels = {}
for _, s in b.spots do labels[s.label] = (labels[s.label] or 0) + 1 end
for k, v in labels do print("  ", k, v) end

-- Rzut z góry: dla każdego piętra rysujemy części geometrii przecinające wysokość głowy (podłoga + 3)
local function plan(f)
	local y = b.floorY[f] + 3
	local rows = {}
	for z = 41, -1, -1 do
		local row = {}
		for x = -29, 65 do
			local ch = " "
			local p = origin + roblox.Vector3.new(x + 0.5, 0, z + 0.5)
			for _, part in b.geometry:GetChildren() do
				local local_ = part.CFrame:PointToObjectSpace(roblox.Vector3.new(p.X, y, p.Z))
				local s = part.Size / 2
				if math.abs(local_.X) <= s.X and math.abs(local_.Y) <= s.Y and math.abs(local_.Z) <= s.Z then
					local n = part.Name
					ch = if n == "Wall" or n == "Lintel" or n == "Fence" then "#" elseif n:match("Stairs") or n == "Landing" then "/" elseif n:match("Door") then "D" else "o"
					break
				end
			end
			table.insert(row, ch)
		end
		table.insert(rows, table.concat(row))
	end
	print(("--- piętro %d (y=%.1f)"):format(f, y))
	print(table.concat(rows, "\n"))
end
for f = 0, 2 do plan(f) end

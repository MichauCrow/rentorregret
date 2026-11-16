-- Pomocnicze funkcje do budowania świata z prostych klocków (wszystko zakotwiczone).
local Parts = {}

local function apply(p: BasePart, color: Color3, material: Enum.Material?)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- Klocek z kolizją (ściany, podłogi, meble)
function Parts.Block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	apply(p, color, material)
	p.Parent = parent
	return p
end

-- Klocek między dwoma rogami (min, max), wygodny do ścian
function Parts.Box(parent: Instance, name: string, min: Vector3, max: Vector3, color: Color3, material: Enum.Material?): Part
	local size = max - min
	return Parts.Block(parent, name, Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z)), CFrame.new((min + max) / 2), color, material)
end

-- Ozdoba bez kolizji i bez trafień promieni (nie przeszkadza w chodzeniu ani w widoczności potworów)
function Parts.Deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Parts.Block(parent, name, size, cframe, color, material)
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Pochylnia (schody) z górną powierzchnią od punktu `from` do punktu `to`
function Parts.Ramp(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3, material: Enum.Material?): Part
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt((from + to) / 2, to)
	frame = frame * CFrame.new(0, -0.5, 0) -- górna powierzchnia leży na linii from-to
	return Parts.Block(parent, name, Vector3.new(width, 1, length), frame, color, material)
end

-- Napis na ścianie części
function Parts.Sign(target: BasePart, face: Enum.NormalId, text: string, color: Color3?, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 240, 200)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 15, 30)
	stroke.Parent = label
	return label
end

-- Napis nad częścią widoczny z daleka
function Parts.Billboard(adornee: BasePart, text: string, color: Color3?, offset: number?, size: Vector2?): TextLabel
	local billboard = Instance.new("BillboardGui")
	local dims = size or Vector2.new(260, 60)
	billboard.Size = UDim2.fromOffset(dims.X, dims.Y)
	billboard.StudsOffset = Vector3.new(0, offset or 3, 0)
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 80
	billboard.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 220, 90)
	label.Text = text
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 15, 30)
	stroke.Parent = label
	return label
end

-- Ciepła lampka (żarówka + PointLight)
function Parts.Lamp(parent: Instance, position: Vector3, brightness: number, range: number, color: Color3?): PointLight
	local bulb = Parts.Deco(parent, "Lamp", Vector3.new(1, 0.6, 1), CFrame.new(position), Color3.fromRGB(255, 225, 160), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color or Color3.fromRGB(255, 200, 130)
	light.Shadows = true
	light.Parent = bulb
	return light
end

return Parts

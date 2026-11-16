-- Klucznik o północy (cała kamienica). Pojawia się tylko, gdy czynsz nie został zapłacony.
-- ZASADA: idzie za każdym, kogo zobaczy (na dowolnym piętrze). Ratunek: brama na podwórku albo szafa.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local MonsterModels = require(ServerScriptService.World.MonsterModels)
local Monster = require(script.Parent.Parent.Monster)

local Landlord = {}
Landlord.__index = Landlord
setmetatable(Landlord, { __index = Monster })

local CFG = MonsterConfig.Landlord
local SEE_RADIUS = 70

function Landlord.new(round, position: Vector3)
	local self = Monster.new(round, "landlord", MonsterModels.Landlord(), position)
	setmetatable(self, Landlord)
	self.target = nil
	self.lastSeen = 0
	self.lastKnown = nil
	self.sinceRepath = math.huge
	return self
end

function Landlord:Update(dt: number)
	if not self.alive then
		return
	end
	self:TryCatch()
	local now = os.clock()
	local building = self.round.building

	-- Najbliższy widoczny gracz
	local best, bestDistance = nil, math.huge
	for _, target in self.round:Targets() do
		local distance = (target.root.CFrame.Position - self:EyePosition()).Magnitude
		if distance < bestDistance and distance <= SEE_RADIUS and self:CanSee(target.root) then
			best, bestDistance = target, distance
		end
	end
	if best then
		self.target = best.player
		self.lastSeen = now
		self.lastKnown = best.root.CFrame.Position - Vector3.new(0, 3, 0)
	end

	self.sinceRepath += dt
	if self.sinceRepath < MonsterConfig.REPATH_INTERVAL then
		return
	end
	self.sinceRepath = 0
	if self.lastKnown and now - self.lastSeen < MonsterConfig.LOSE_SIGHT_TIME * 2 then
		self:MoveTo(self.lastKnown, CFG.speed)
	elseif not self:IsMoving() then
		-- Szuka: losowe miejsce na losowym piętrze (gracze, którzy się chowają, mają szansę)
		local floor = math.random(0, #building.patrol)
		local points = if math.random() < 0.5 then building.patrol[floor] else building.peeks[floor]
		if points and #points > 0 then
			self:MoveTo(points[math.random(1, #points)], CFG.speed * 0.75)
		end
	end
end

return Landlord

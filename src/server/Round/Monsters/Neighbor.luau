-- Cichy Sąsiad (1. piętro). ZASADA: słyszy bieganie. Kto idzie powoli, jest bezpieczny;
-- z bliska widzi tylko tych, którzy się ruszają (stój nieruchomo albo schowaj się w szafie).
-- Stany: patrol (korytarz, czasem zagląda do mieszkań) -> nasłuch (idzie sprawdzić hałas) -> pościg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local MonsterModels = require(ServerScriptService.World.MonsterModels)
local Monster = require(script.Parent.Parent.Monster)

local Neighbor = {}
Neighbor.__index = Neighbor
setmetatable(Neighbor, { __index = Monster })

local FLOOR = 1
local CFG = MonsterConfig.Neighbor
local ALERT_COOLDOWN = 6
local MOVING_SPEED = 2

function Neighbor.new(round, position: Vector3)
	local self = Monster.new(round, "neighbor", MonsterModels.Neighbor(), position)
	setmetatable(self, Neighbor)
	self.state = "patrol"
	self.waitUntil = 0
	self.patrolIndex = 1
	self.target = nil
	self.lastSeen = 0
	self.alerted = {}
	self.sinceRepath = 0
	-- Animacje: uszy strzygą, gdy nasłuchuje; płomień świecy drga; czubek szlafmycy się kiwa
	self:Animate("Ear", function(t, base)
		local listening = self.mood == "curious" or self.mood == "alert"
		local speed = if listening then 22 else 2
		local amount = if listening then 0.3 else 0.05
		return base * CFrame.Angles(0, 0, math.sin(t * speed) * amount)
	end)
	self:Animate("Flame", function(t, base)
		return base * CFrame.new(math.sin(t * 13) * 0.04, math.abs(math.sin(t * 9)) * 0.06, math.cos(t * 17) * 0.04)
	end)
	local capHinge = CFrame.new(0, 10.2, 0.1)
	for _, name in { "NightcapTip", "NightcapPompom" } do
		self:Animate(name, function(t, base)
			return capHinge * CFrame.Angles(math.sin(t * 2.2) * 0.15, 0, math.sin(t * 1.7) * 0.12) * capHinge:Inverse() * base
		end)
	end
	return self
end

function Neighbor:Alert(player: Player, text: string)
	local now = os.clock()
	if (self.alerted[player] or 0) + ALERT_COOLDOWN > now then
		return
	end
	self.alerted[player] = now
	self.round:Event(player, "alert", { text = text, kind = "bad", monster = "neighbor" })
end

function Neighbor:NextPatrolPoint(): Vector3
	local building = self.round.building
	if math.random() < CFG.peekChance and #building.peeks[FLOOR] > 0 then
		return building.peeks[FLOOR][math.random(1, #building.peeks[FLOOR])]
	end
	local points = building.patrol[FLOOR]
	self.patrolIndex = self.patrolIndex % #points + 1
	return points[self.patrolIndex]
end

-- Najgłośniejszy (najbliższy biegnący) gracz na piętrze w zasięgu słuchu
function Neighbor:Listen()
	local best, bestDistance = nil, math.huge
	for _, target in self.round:Targets() do
		if target.floor == FLOOR and Monster.SpeedOf(target.root) > GameConfig.NOISY_SPEED then
			local distance = self:DistanceTo(target.root.CFrame.Position)
			if distance <= CFG.hearRadius * target.state.hearing and distance < bestDistance then
				best, bestDistance = target, distance
			end
		end
	end
	return best
end

-- Ruszający się gracz blisko i w zasięgu wzroku
function Neighbor:Look()
	for _, target in self.round:Targets() do
		if target.floor == FLOOR and Monster.SpeedOf(target.root) > MOVING_SPEED then
			if self:DistanceTo(target.root.CFrame.Position) <= CFG.seeRadius and self:CanSee(target.root) then
				return target
			end
		end
	end
	return nil
end

function Neighbor:StartChase(target)
	if self.state ~= "chase" then
		self:Alert(target.player, "😱 Sąsiad Cię zobaczył! Uciekaj albo schowaj się w szafie!")
	end
	self.state = "chase"
	self.target = target.player
	self.lastSeen = os.clock()
	self.sinceRepath = math.huge
end

local MOODS = { patrol = nil, investigate = "curious", lookAround = "curious", chase = "alert" }

function Neighbor:Update(dt: number)
	if not self.alive then
		return
	end
	self:SetMood(MOODS[self.state])
	-- Łapie tylko w pościgu: kto stoi nieruchomo albo idzie powoli, jest bezpieczny
	if self.state == "chase" then
		self:TryCatch()
	end
	local now = os.clock()

	if self.state == "chase" then
		local found = nil
		for _, target in self.round:Targets() do
			if target.player == self.target then
				found = target
			end
		end
		if not found or found.floor ~= FLOOR or self:DistanceTo(found.root.CFrame.Position) > CFG.chaseGiveUpRadius then
			self.state = "lookAround"
			self.waitUntil = now + CFG.lookAroundTime
			self:Stop()
			return
		end
		if self:CanSee(found.root) then
			self.lastSeen = now
		elseif now - self.lastSeen > MonsterConfig.LOSE_SIGHT_TIME then
			self.state = "lookAround"
			self.waitUntil = now + CFG.lookAroundTime
			self:Stop()
			return
		end
		self.sinceRepath += dt
		if self.sinceRepath >= MonsterConfig.REPATH_INTERVAL then
			self.sinceRepath = 0
			self:MoveTo(found.root.CFrame.Position - Vector3.new(0, 3, 0), CFG.chaseSpeed)
		end
		return
	end

	local seen = self:Look()
	if seen then
		self:StartChase(seen)
		return
	end
	local heard = self:Listen()
	if heard then
		self:Alert(heard.player, "🤫 Ćśś! Sąsiad usłyszał Twoje kroki... Idź powoli!")
		self.state = "investigate"
		self:MoveTo(heard.root.CFrame.Position - Vector3.new(0, 3, 0), CFG.investigateSpeed)
		return
	end

	if self.state == "investigate" then
		if not self:IsMoving() then
			self.state = "lookAround"
			self.waitUntil = now + CFG.lookAroundTime
		end
	elseif self.state == "lookAround" then
		-- Rozgląda się: obraca się powoli w miejscu
		self.look = (CFrame.Angles(0, dt * 1.5, 0) * CFrame.new(self.look)).Position
		if now >= self.waitUntil then
			self.state = "patrol"
		end
	elseif self.state == "patrol" then
		if not self:IsMoving() then
			if self.waitUntil == 0 then
				self.waitUntil = now + math.random(10, 25) / 10
			elseif now >= self.waitUntil then
				self.waitUntil = 0
				self:MoveTo(self:NextPatrolPoint(), CFG.patrolSpeed)
			end
		end
	end
end

return Neighbor

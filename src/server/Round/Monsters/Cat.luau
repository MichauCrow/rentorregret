-- Mruczek (2. piętro). ZASADA: idzie za światłem latarki. Zgaś latarkę, a straci zainteresowanie.
-- Stany: drzemka na poduszce -> spacer po korytarzu -> skradanie się do światła -> "przytulenie" (złapanie).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local NightConfig = require(ReplicatedStorage.Shared.Config.NightConfig)
local MonsterModels = require(ServerScriptService.World.MonsterModels)
local Monster = require(script.Parent.Parent.Monster)

local Cat = {}
Cat.__index = Cat
setmetatable(Cat, { __index = Monster })

local FLOOR = 2
local CFG = MonsterConfig.Cat
local LOSE_INTEREST = 1.5
local ALERT_COOLDOWN = 8
local MOODS = { nap = "sleep", stalk = "alert" }

function Cat.new(round, position: Vector3)
	local self = Monster.new(round, "cat", MonsterModels.Cat(), position)
	setmetatable(self, Cat)
	self.home = position
	self.state = "nap"
	self.napTime = CFG.napTime * NightConfig.Value(round.night, "catNap")
	self.lightRadius = CFG.lightRadius * NightConfig.Value(round.night, "catLight")
	self.waitUntil = os.clock() + self.napTime
	self.target = nil
	self.lastLight = 0
	self.sinceRepath = 0
	self.alerted = {}
	self.eyes = {}
	for _, descendant in self.model:GetDescendants() do
		if descendant.Name == "Eye" and descendant:IsA("BasePart") then
			table.insert(self.eyes, descendant)
		end
	end
	self.glow = self.model:FindFirstChild("EyeGlow", true)
	return self
end

function Cat:SetExcited(excited: boolean)
	for _, eye in self.eyes do
		eye.Color = if excited then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(255, 225, 60)
	end
	if self.glow then
		self.glow.Brightness = if excited then 2 else 0.6
		self.glow.Range = if excited then 14 else 9
	end
end

-- Najbliższy gracz z włączoną latarką, którego światło kot widzi
function Cat:FindLight()
	local best, bestDistance = nil, math.huge
	for _, target in self.round:Targets() do
		if target.floor == FLOOR and target.state.flashlight then
			local distance = self:DistanceTo(target.root.CFrame.Position)
			if distance <= self.lightRadius and distance < bestDistance and self:CanSee(target.root) then
				best, bestDistance = target, distance
			end
		end
	end
	return best
end

-- Reżyser nocy: kot się budzi i idzie w stronę graczy (bez skradania: łapie tylko za światłem)
function Cat:WakeTowards(position: Vector3)
	if self.state == "stalk" then
		return
	end
	self.state = "wander"
	self.waitUntil = -1
	self:MoveTo(position, self:Speed(CFG.wanderSpeed * 1.4))
end

function Cat:Update(dt: number)
	if not self.alive then
		return
	end
	self:SetMood(MOODS[self.state])
	-- Łapie tylko wtedy, gdy idzie za światłem (zasada musi być uczciwa: zgaszona latarka = bezpiecznie)
	if self.state == "stalk" then
		self:TryCatch(CFG.catchDistance)
	end
	local now = os.clock()
	local light = self:FindLight()

	if light then
		if self.state ~= "stalk" then
			self:SetExcited(true)
			if (self.alerted[light.player] or 0) + ALERT_COOLDOWN < now then
				self.alerted[light.player] = now
				self.round:Event(light.player, "alert", { text = "🐾 Mruczek zobaczył Twoje światło! Zgaś latarkę!", kind = "bad", monster = "cat" })
			end
		end
		self.state = "stalk"
		self.target = light.player
		self.lastLight = now
		self.sinceRepath += dt
		if self.sinceRepath >= MonsterConfig.REPATH_INTERVAL then
			self.sinceRepath = 0
			self:MoveTo(light.root.CFrame.Position - Vector3.new(0, 3, 0), self:Speed(CFG.stalkSpeed))
		end
		return
	end

	if self.state == "stalk" then
		-- Światło zgasło: kot dochodzi jeszcze chwilę do ostatniego miejsca, potem traci zainteresowanie
		if now - self.lastLight > LOSE_INTEREST then
			self:SetExcited(false)
			self.state = "wander"
			self.target = nil
			self:Stop()
			self.waitUntil = now + 2
		end
		return
	end

	if self.state == "nap" then
		if now >= self.waitUntil then
			self.state = "wander"
			self.waitUntil = 0
		end
	elseif self.state == "wander" then
		if not self:IsMoving() then
			if self.waitUntil == 0 then
				local building = self.round.building
				local points = if math.random() < 0.3 then { self.home } else building.patrol[FLOOR]
				self:MoveTo(points[math.random(1, #points)], self:Speed(CFG.wanderSpeed))
				self.waitUntil = -1
			elseif self.waitUntil == -1 then
				-- Doszedł: czasem drzemka, czasem dalej
				if math.random() < 0.35 then
					self.state = "nap"
					self.waitUntil = now + self.napTime
				else
					self.waitUntil = now + 2
				end
			elseif now >= self.waitUntil then
				self.waitUntil = 0
			end
		end
	end
end

return Cat

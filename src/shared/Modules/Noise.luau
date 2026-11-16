-- Hałas gracza: z jakiej odległości potwory (Cichy Sąsiad) go słyszą. Ten sam wzór liczy serwer
-- (słuch Sąsiada) i klient (pierścień hałasu pod postacią), więc to, co widać, jest dokładnie tym, co działa.
local GameConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("GameConfig"))

local Noise = {}

-- speed: pozioma prędkość, carried/capacity: kieszenie, hearing: mnożnik (Cichobiegi x noc)
function Noise.Radius(speed: number, carried: number, capacity: number, hearing: number): number
	if speed < GameConfig.MOVING_SPEED then
		return 0
	end
	local ratio = if capacity > 0 then math.clamp(carried / capacity, 0, 1) else 0
	local jingle = 0
	if ratio > GameConfig.JINGLE_FROM then
		jingle = GameConfig.NOISE_COIN_RADIUS * (ratio - GameConfig.JINGLE_FROM) / (1 - GameConfig.JINGLE_FROM)
	end
	local radius = jingle
	if speed > GameConfig.NOISY_SPEED then
		-- Bieg z pełnymi kieszeniami słychać jeszcze dalej
		radius = GameConfig.NOISE_RUN_RADIUS + jingle * 0.4
	end
	return radius * hearing
end

-- Czy kieszenie brzęczą (do dźwięku i podpowiedzi)
function Noise.Jingles(carried: number, capacity: number): boolean
	return capacity > 0 and carried / capacity > GameConfig.JINGLE_FROM
end

return Noise

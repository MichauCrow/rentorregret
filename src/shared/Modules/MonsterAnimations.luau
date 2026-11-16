-- Animacje części potworów (rysuje je u siebie każdy gracz w MonsterRenderer).
-- fn(t, base, mood) zwraca położenie części względem stóp potwora; base = położenie wyjściowe części,
-- mood = nastrój z serwera ("sleep" | "curious" | "alert" | nil).
local function hinge(point: CFrame, rotation: CFrame, base: CFrame): CFrame
	return point * rotation * point:Inverse() * base
end

local capHinge = CFrame.new(0, 10.2, 0.1)
local tailHinge = CFrame.new(0, 3, 4.4)
local keyHinge = CFrame.new(1.5, 6.3, -3.1)

local function nightcap(t: number, base: CFrame): CFrame
	return hinge(capHinge, CFrame.Angles(math.sin(t * 2.2) * 0.15, 0, math.sin(t * 1.7) * 0.12), base)
end

local function catEar(t: number, base: CFrame): CFrame
	local twitch = if math.sin(t * 0.7) > 0.95 then math.sin(t * 40) * 0.25 else 0
	return base * CFrame.Angles(0, 0, twitch)
end

local function key(t: number, base: CFrame): CFrame
	return hinge(keyHinge, CFrame.Angles(math.sin(t * 4) * 0.35, 0, 0), base)
end

return {
	neighbor = {
		-- Uszy strzygą, gdy nasłuchuje
		{
			part = "Ear",
			fn = function(t, base, mood)
				local listening = mood == "curious" or mood == "alert"
				return base * CFrame.Angles(0, 0, math.sin(t * (if listening then 22 else 2)) * (if listening then 0.3 else 0.05))
			end,
		},
		-- Płomień świecy drga
		{
			part = "Flame",
			fn = function(t, base)
				return base * CFrame.new(math.sin(t * 13) * 0.04, math.abs(math.sin(t * 9)) * 0.06, math.cos(t * 17) * 0.04)
			end,
		},
		{ part = "NightcapTip", fn = nightcap },
		{ part = "NightcapPompom", fn = nightcap },
	},
	cat = {
		-- Ogon macha: szybko, gdy kot poluje, powoli w czasie drzemki
		{
			part = "Tail",
			fn = function(t, base, mood)
				local speed, amount = 1.8, 0.3
				if mood == "alert" then
					speed, amount = 6, 0.5
				elseif mood == "sleep" then
					speed, amount = 0.8, 0.12
				end
				return hinge(tailHinge, CFrame.Angles(0, math.sin(t * speed) * amount, 0), base)
			end,
		},
		{ part = "Ear", fn = catEar },
		{ part = "EarInside", fn = catEar },
	},
	landlord = {
		-- Wielki klucz kołysze się w dłoni
		{ part = "KeyShaft", fn = key },
		{ part = "KeyBow", fn = key },
		{ part = "KeyBit", fn = key },
	},
}

-- Animacje części potworów (rysuje je u siebie każdy gracz w MonsterRenderer).
-- Każdy wpis: part = nazwa części, fn(t, mood) = obrót/przesunięcie (CFrame) w danej chwili,
-- hinge = nazwa zawiasu (atrybut modelu "Hinge<nazwa>", punkt względem stóp potwora). Z zawiasem część
-- obraca się wokół tego punktu (ogon, klucz), bez zawiasu wokół własnego środka (uszy, płomień).
-- mood = nastrój z serwera: "sleep" | "curious" | "alert" | nil.
local function nightcap(t: number): CFrame
	return CFrame.Angles(math.sin(t * 2.2) * 0.15, 0, math.sin(t * 1.7) * 0.12)
end

local function catEar(t: number): CFrame
	local twitch = if math.sin(t * 0.7) > 0.95 then math.sin(t * 40) * 0.25 else 0
	return CFrame.Angles(0, 0, twitch)
end

local function key(t: number, mood: string?): CFrame
	local speed = if mood == "alert" then 6 else 3
	return CFrame.Angles(math.sin(t * speed) * 0.3, 0, 0)
end

local function tail(t: number, mood: string?): CFrame
	local speed, amount = 1.8, 0.3
	if mood == "alert" then
		speed, amount = 6, 0.5
	elseif mood == "sleep" then
		speed, amount = 0.8, 0.12
	end
	return CFrame.Angles(0, math.sin(t * speed) * amount, 0)
end

return {
	neighbor = {
		-- Uszy strzygą, gdy nasłuchuje
		{
			part = "Ear",
			fn = function(t: number, mood: string?): CFrame
				local listening = mood == "curious" or mood == "alert"
				return CFrame.Angles(0, 0, math.sin(t * (if listening then 22 else 2)) * (if listening then 0.3 else 0.05))
			end,
		},
		-- Płomień świecy drga
		{
			part = "Flame",
			fn = function(t: number): CFrame
				return CFrame.new(math.sin(t * 13) * 0.04, math.abs(math.sin(t * 9)) * 0.06, math.cos(t * 17) * 0.04)
			end,
		},
		{ part = "NightcapTip", hinge = "Cap", fn = nightcap },
		{ part = "NightcapPompom", hinge = "Cap", fn = nightcap },
	},
	cat = {
		-- Ogon macha: szybko, gdy kot poluje, powoli w czasie drzemki
		{ part = "Tail", hinge = "Tail", fn = tail },
		{ part = "Ear", fn = catEar },
		{ part = "EarInside", fn = catEar },
	},
	landlord = {
		-- Wielki klucz kołysze się w dłoni
		{ part = "KeyShaft", hinge = "Key", fn = key },
		{ part = "KeyBow", hinge = "Key", fn = key },
		{ part = "KeyHole", hinge = "Key", fn = key },
		{ part = "KeyBit", hinge = "Key", fn = key },
		{ part = "KeyTooth", hinge = "Key", fn = key },
	},
}

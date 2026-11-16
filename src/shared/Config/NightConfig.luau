-- Noce z modyfikatorem: każdego dnia (wg czasu UTC) obowiązuje inna zasada, ta sama na wszystkich serwerach.
-- Mnożniki, których noc nie ustawia, wynoszą 1.
local NightConfig = {}

NightConfig.Nights = {
	{ id = "calm", icon = "🌙", name = "Spokojna noc", description = "Zwykła noc w kamienicy." },
	{
		id = "blackout",
		icon = "🔌",
		name = "Noc bez prądu",
		description = "Lampy prawie nie świecą, ale baterie są większe. Nagrody x1.3!",
		lights = 0.15,
		battery = 1.6,
		reward = 1.3,
	},
	{
		id = "sleepwalker",
		icon = "🚶",
		name = "Sąsiad lunatyk",
		description = "Cichy Sąsiad chodzi szybciej i słyszy lepiej. Nagrody x1.3!",
		neighborSpeed = 1.3,
		hearing = 1.2,
		reward = 1.3,
	},
	{
		id = "expensive",
		icon = "💸",
		name = "Drogi miesiąc",
		description = "Czynsz x1.5, ale nagrody x2!",
		rent = 1.5,
		reward = 2,
	},
	{
		id = "hungryCat",
		icon = "🐟",
		name = "Głodny Mruczek",
		description = "Mruczek mało śpi i widzi światło z daleka. Na 2. piętrze więcej monet!",
		catNap = 0.4,
		catLight = 1.3,
		floor2Coins = 1.5,
	},
}

-- Noc na dziś (albo na podany dzień: liczba dni od 1970-01-01)
function NightConfig.Today(day: number?)
	local index = (day or os.time() // 86400) % #NightConfig.Nights + 1
	return NightConfig.Nights[index]
end

function NightConfig.ById(id: string?)
	for _, night in NightConfig.Nights do
		if night.id == id then
			return night
		end
	end
	return NightConfig.Nights[1]
end

-- Mnożnik z nocy (brak = 1)
function NightConfig.Value(night, key: string): number
	local value = night and night[key]
	return if type(value) == "number" then value else 1
end

return NightConfig

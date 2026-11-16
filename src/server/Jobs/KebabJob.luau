-- Dowóz kebabów (pierwsza praca z dowozem): weź kebab z okienka budki obok ogrodu, wsiądź na rower ze stojaka
-- (ręce na kierownicy, nogi na pedałach), zawieź pod wskazany dom, wróć i odstaw rower. Cała logika: Lib.DeliveryJob.
local ServerScriptService = game:GetService("ServerScriptService")

local DeliveryJob = require(ServerScriptService.Lib.DeliveryJob)

return DeliveryJob.Create({
	jobId = "kebab",
	site = "KebabStand",
	pickupPart = "StartPart",
	parked = "ParkedBike",
	vehicle = "bike",
	carrier = "KebabBasket",
	fx = "pizza",
	package = { name = "KebabBox", size = Vector3.new(1.2, 0.5, 0.9), color = Color3.fromRGB(205, 210, 215), material = Enum.Material.Foil },
	pile = { size = Vector3.new(2.6, 0.6, 1.2), color = Color3.fromRGB(205, 210, 215), material = Enum.Material.Foil },
	texts = {
		take = "Weź kebab z okienka budki",
		takeAction = "Weź kebab",
		takeObject = "Okienko",
		takeGuide = "🥙 Weź kebab",
		mount = "Wsiądź na rower obok budki 🚲",
		back = "Wróć pod budkę i odstaw rower 🅿️",
		parkFirst = "Najpierw odstaw rower przy budce 🅿️",
		taken = "Ten rower jest zajęty. Weź inny!",
		mountAction = "Wsiądź na rower",
		parkAction = "Odstaw rower",
		vehicleObject = "Rower",
		mountLabel = "🚲 Wsiądź!",
		deliver = "Zawieź kebab pod dom nr %d (żółty znacznik)",
		deliverAction = "Dostarcz kebab",
		icon = "🥙",
	},
})

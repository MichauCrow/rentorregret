-- Kosmetyki: TYLKO wygląd, żadnej przewagi w grze i żadnych losowych skrzynek.
-- Cena: tokens = Klucze Lokatora (zdobywane w grze), product = klucz z DevProducts (Robux)
-- albo pass = klucz z GamePasses (Robux, kupowany raz na zawsze).
--
-- JAK WŁĄCZYĆ ZAKUPY ZA ROBUX:
-- 1. Creator Hub > Twoja gra > Monetization > Passes: utwórz Game Pass "VIP" i "Kostium Dyni".
--    Wklej ich ID w GamePasses.vip.id i GamePasses.halloween.id. Dopóki id = 0, sklep pokazuje "Wkrótce".
-- 2. (opcjonalnie) Monetization > Developer Products: produkty z DevProducts, ID w pole id.
local CosmeticsConfig = {}

CosmeticsConfig.Kinds = {
	trail = "Ślad za postacią",
	title = "Tytuł nad głową",
	wall = "Kolor ścian",
	sparkle = "Kolor iskierek",
	costume = "Strój",
}

CosmeticsConfig.Items = {
	trailSparkle = { kind = "trail", name = "Iskierki", emoji = "✨", tokens = 25, colors = { Color3.fromRGB(255, 255, 200), Color3.fromRGB(255, 220, 120) } },
	trailHearts = { kind = "trail", name = "Różowy ślad", emoji = "💖", tokens = 30, colors = { Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 200, 230) } },
	trailRainbow = { kind = "trail", name = "Tęczowy ślad", emoji = "🌈", tokens = 40, colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 220, 110), Color3.fromRGB(80, 160, 255), Color3.fromRGB(190, 110, 255) } },
	trailGold = { kind = "trail", name = "Złoty ślad", emoji = "🌟", pass = "vip", colors = { Color3.fromRGB(255, 205, 50), Color3.fromRGB(255, 240, 150) } },

	titleCrew = { kind = "title", name = "Ekipa Sprzątająca", emoji = "🧽", tokens = 10, color = Color3.fromRGB(120, 220, 255) },
	titleHandy = { kind = "title", name = "Złota Rączka", emoji = "🔧", tokens = 15, color = Color3.fromRGB(255, 200, 80) },
	titleStar = { kind = "title", name = "Gwiazda Kamienicy", emoji = "⭐", tokens = 20, color = Color3.fromRGB(255, 230, 90) },
	titleVip = { kind = "title", name = "VIP Lokator", emoji = "👑", pass = "vip", color = Color3.fromRGB(255, 205, 50) },

	wallSunny = { kind = "wall", name = "Słoneczne ściany", emoji = "☀️", tokens = 15, color = Color3.fromRGB(255, 235, 150) },
	wallPink = { kind = "wall", name = "Pastelowy róż", emoji = "🌸", tokens = 20, color = Color3.fromRGB(250, 200, 220) },
	wallMint = { kind = "wall", name = "Miętowe ściany", emoji = "🌿", tokens = 20, color = Color3.fromRGB(190, 240, 215) },
	wallNight = { kind = "wall", name = "Nocne niebo", emoji = "🌌", product = "nightWalls", color = Color3.fromRGB(70, 70, 130) },

	sparkleGold = { kind = "sparkle", name = "Złote iskierki", emoji = "💛", tokens = 15, color = Color3.fromRGB(255, 215, 60) },
	sparklePink = { kind = "sparkle", name = "Różowe iskierki", emoji = "💗", product = "pinkSparkle", color = Color3.fromRGB(255, 130, 200) },

	-- Stroje (CosmeticsService.applyCostume dokłada części do postaci)
	costumeVip = { kind = "costume", name = "Złoty strój VIP", emoji = "👑", pass = "vip" },
	costumePumpkin = { kind = "costume", name = "Kostium Dyni", emoji = "🎃", pass = "halloween" },
}

CosmeticsConfig.Order = {
	"trailSparkle", "trailHearts", "trailRainbow", "trailGold",
	"titleCrew", "titleHandy", "titleStar", "titleVip",
	"wallSunny", "wallPink", "wallMint", "wallNight",
	"sparkleGold", "sparklePink",
	"costumeVip", "costumePumpkin",
}

-- Developer Products (Robux): klucz -> id produktu z Creator Hub (0 = jeszcze nie utworzony)
CosmeticsConfig.DevProducts = {
	nightWalls = { id = 0, item = "wallNight" },
	pinkSparkle = { id = 0, item = "sparklePink" },
}

-- Game Passy (Robux): kupowane raz, na zawsze. grants = co dostaje gracz (wszystko od razu zakładamy).
-- event = "halloween": oferta widoczna tylko w czasie eventu (JobsConfig.Jobs.cans.halloween), kupione zostaje.
CosmeticsConfig.GamePasses = {
	vip = { id = 2058562273, name = "VIP", emoji = "👑", grants = { "titleVip", "trailGold", "costumeVip", "sparkleGold" } },
	halloween = { id = 2057716277, name = "Kostium Dyni", emoji = "🎃", event = "halloween", grants = { "costumePumpkin" } },
	stylePack = { id = 0, name = "Pakiet Stylu", grants = { "wallNight", "sparklePink" } },
}

CosmeticsConfig.MAX_RECEIPTS = 100 -- ile ostatnich zakupów pamiętamy (ochrona przed podwójnym przyznaniem)

return CosmeticsConfig

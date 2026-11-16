-- Sklep "Mebelkowo": meble (komfort) i sprzęt (szybsze sprzątanie, niższe rachunki, robot).
-- Wszystko za monety z gry. Kosmetyki za Robux dojdą w Fazie 14 i nie będą dawać przewagi.
local ShopConfig = {}

ShopConfig.Categories = {
	{ id = "furniture", name = "Meble" },
	{ id = "equipment", name = "Sprzęt" },
}

-- spot: "floor" = miejsce przy ścianie, "rug" = środek pokoju
-- holdMultiplier: skraca czas sprzątania danego rodzaju brudu (0.75 = o 25% szybciej)
-- eco: obniżka rachunków (wartości w EconomyConfig.EcoUpgrades)
ShopConfig.Items = {
	plant = { category = "furniture", name = "Roślinka", emoji = "🌿", price = 30, comfort = 3, unlockMonth = 1, spot = "floor" },
	lamp = { category = "furniture", name = "Lampka", emoji = "💡", price = 40, comfort = 4, unlockMonth = 1, spot = "floor" },
	rug = { category = "furniture", name = "Dywan", emoji = "🧶", price = 90, comfort = 6, unlockMonth = 1, spot = "rug" },
	armchair = { category = "furniture", name = "Fotel", emoji = "🛋️", price = 120, comfort = 8, unlockMonth = 2, spot = "floor" },
	bookshelf = { category = "furniture", name = "Regał z książkami", emoji = "📚", price = 180, comfort = 9, unlockMonth = 3, spot = "floor" },
	tv = { category = "furniture", name = "Telewizor", emoji = "📺", price = 250, comfort = 12, unlockMonth = 3, spot = "floor" },
	aquarium = { category = "furniture", name = "Akwarium", emoji = "🐠", price = 400, comfort = 15, unlockMonth = 5, spot = "floor" },
	sofa = { category = "furniture", name = "Sofa premium", emoji = "🛋️", price = 900, comfort = 22, unlockMonth = 7, spot = "floor" },
	-- Wyposażenie pokoi (łóżka, biurka, sprzęt)
	beanBag = { category = "furniture", name = "Pufa", emoji = "🟣", price = 70, comfort = 4, unlockMonth = 1, spot = "floor" },
	chair = { category = "furniture", name = "Krzesło", emoji = "🪑", price = 60, comfort = 3, unlockMonth = 1, spot = "floor" },
	table = { category = "furniture", name = "Stół", emoji = "🍽️", price = 140, comfort = 6, unlockMonth = 1, spot = "floor" },
	desk = { category = "furniture", name = "Biurko", emoji = "✏️", price = 160, comfort = 6, unlockMonth = 2, spot = "floor" },
	printer = { category = "furniture", name = "Drukarka", emoji = "🖨️", price = 150, comfort = 4, unlockMonth = 2, spot = "floor" },
	bed = { category = "furniture", name = "Łóżko", emoji = "🛏️", price = 300, comfort = 10, unlockMonth = 2, spot = "floor" },
	wardrobe = { category = "furniture", name = "Szafa", emoji = "🚪", price = 220, comfort = 7, unlockMonth = 2, spot = "floor" },
	computer = { category = "furniture", name = "Komputer", emoji = "💻", price = 400, comfort = 10, unlockMonth = 3, spot = "floor" },
	grandClock = { category = "furniture", name = "Zegar stojący", emoji = "🕰️", price = 260, comfort = 8, unlockMonth = 3, spot = "floor" },
	gamingChair = { category = "furniture", name = "Fotel gamingowy", emoji = "🎮", price = 450, comfort = 11, unlockMonth = 4, spot = "floor" },
	bunkBed = { category = "furniture", name = "Łóżko piętrowe", emoji = "🛏️", price = 550, comfort = 14, unlockMonth = 4, spot = "floor" },
	piano = { category = "furniture", name = "Pianino", emoji = "🎹", price = 700, comfort = 16, unlockMonth = 5, spot = "floor" },

	broom = { category = "equipment", name = "Lepsza miotła", emoji = "🧹", price = 60, unlockMonth = 1, description = "Śmieci 25% szybciej", holdMultiplier = { trash = 0.75 } },
	sponge = { category = "equipment", name = "Gąbka mistrz", emoji = "🧽", price = 80, unlockMonth = 1, description = "Naczynia 40% szybciej", holdMultiplier = { dishes = 0.6 } },
	slipper = { category = "equipment", name = "Złoty klapek", emoji = "🥿", price = 50, unlockMonth = 2, description = "Robaki 60% szybciej", holdMultiplier = { bug = 0.4 } },
	mop = { category = "equipment", name = "Mop turbo", emoji = "🧼", price = 150, unlockMonth = 2, description = "Plamy i pleśń 40% szybciej", holdMultiplier = { stain = 0.6, mold = 0.6 } },
	led = { category = "equipment", name = "Żarówki LED", emoji = "💡", price = 120, unlockMonth = 2, description = "Rachunki -20%" },
	aerator = { category = "equipment", name = "Perlator", emoji = "🚰", price = 100, unlockMonth = 3, description = "Rachunki -20%" },
	robot = { category = "equipment", name = "Robot sprzątający", emoji = "🤖", price = 600, unlockMonth = 5, description = "Sam sprząta 1 rzecz co 30 s", robotInterval = 30 },
	-- Większe worki na butelki (liczy się największy kupiony; zwykły worek mieści JobsConfig.Jobs.cans.bagCapacity)
	bagLarge = { category = "equipment", name = "Duży worek", emoji = "🎒", price = 120, unlockMonth = 1, description = "Worek na 25 butelek", bagCapacity = 25 },
	bagHuge = { category = "equipment", name = "Wielki worek", emoji = "👜", price = 350, unlockMonth = 3, description = "Worek na 40 butelek", bagCapacity = 40 },
}

-- Rzadkie meble zdobywane w grze (osiągnięcia, kalendarz). Nie ma ich w sklepie.
ShopConfig.Items.trophy = { category = "reward", name = "Puchar Weterana", emoji = "🏆", price = 0, comfort = 6, unlockMonth = 1, spot = "floor" }
ShopConfig.Items.neonSign = { category = "reward", name = "Neon Mistrza Fachu", emoji = "✨", price = 0, comfort = 8, unlockMonth = 1, spot = "floor" }
ShopConfig.Items.canShelf = { category = "reward", name = "Półka ze złotą puszką", emoji = "🥫", price = 0, comfort = 5, unlockMonth = 1, spot = "floor" }
ShopConfig.Items.starLamp = { category = "reward", name = "Lampa z gwiazdami", emoji = "⭐", price = 0, comfort = 7, unlockMonth = 1, spot = "floor" }

ShopConfig.Order = {
	"plant", "chair", "beanBag", "lamp", "rug", "table", "armchair", "desk", "printer", "bed", "bookshelf", "wardrobe",
	"tv", "grandClock", "computer", "aquarium", "gamingChair", "bunkBed", "piano", "sofa",
	"bagLarge", "bagHuge",
	"broom", "sponge", "slipper", "mop", "led", "aerator", "robot",
}

return ShopConfig

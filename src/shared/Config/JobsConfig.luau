-- Definicje prac (zatwierdzone w Fazie 1). Nowa praca = wpis tutaj + moduł w ServerScriptService.Jobs.
-- implemented = true oznacza, że praca ma już swoją minigrę.
local JobsConfig = {}

JobsConfig.HOLD_TOLERANCE = 0.8 -- akceptujemy 80% czasu przytrzymania (opóźnienia sieci)
JobsConfig.START_DISTANCE = 14 -- jak blisko miejsca pracy trzeba stać, żeby zacząć zmianę
JobsConfig.STREAK_BONUS = 0.10 -- "Seria fachowca": 3x 3 gwiazdki z rzędu = +10% do następnej zmiany
-- Zmiany trwają zawsze do końca czasu, a zadania się nie kończą. Każde zadanie ponad cel = +5% (maks. +30%).
JobsConfig.OVER_TARGET_BONUS = 0.05
JobsConfig.OVER_TARGET_MAX = 0.30
-- Praca w ekipie: współlokatorzy w tej samej pracy w tym samym czasie dostają +20%,
-- jeśli każdy zrobił co najmniej 25% celu
JobsConfig.COOP_BONUS = 0.20
JobsConfig.COOP_MIN_SHARE = 0.25
-- Combo: kolejne zadanie w ciągu comboWindow sekund (domyślnie COMBO_WINDOW) przedłuża serię.
-- Najdłuższa seria w zmianie daje premię: seria przez cały cel = COMBO_MAX_BONUS (+15%).
JobsConfig.COMBO_WINDOW = 8
JobsConfig.COMBO_MAX_BONUS = 0.15
JobsConfig.LevelNames = { "ŁATWY", "ŚREDNI", "TRUDNY" }

JobsConfig.Order = { "cans", "cleaner", "gardener", "kebab", "cashier", "pizza", "petsitter", "mechanic", "freelancer", "scrapPro" }

JobsConfig.Jobs = {
	-- Praca bez wymagań, zawsze dostępna: gwarantuje, że gracz zawsze może zarobić
	-- Identyfikator zostaje "cans" (zapisy graczy), ale zbiera się butelki kaucyjne
	cans = {
		name = "Zbieracz butelek",
		unlockMonth = 1,
		implemented = true,
		payPerItem = 2,
		bagCapacity = 15,
		pickupHold = 0.1, -- sekundy przytrzymania przy podnoszeniu (prawie od razu)
		minPickupInterval = 0.3, -- serwer: minimalny odstęp między butelkami
		baseCans = 24, -- butelek w parku przy 1 graczu
		cansPerExtraPlayer = 6,
		respawnDelay = 2,
		trashBottles = { 0, 1, 2, 3 },
		-- Kosze w mieście: przeszukanie (minigra) daje losową nagrodę; każdy kosz u każdego gracza ma osobny cooldown
		binCooldown = 150, -- sekundy, zanim ten sam gracz znowu przeszuka ten sam kosz
		binClicks = { 5, 15 }, -- ile kliknięć "SZUKAJ!" w minigrze (losowo od-do)
		binMinTime = 1.2, -- szybciej nie da się przeszukać (serwer)
		binLoot = { -- wagi nagród (dynie tylko w czasie Halloween; poza nim ich waga przechodzi na monety)
			{ kind = "bottles", weight = 45, min = 1, max = 3 },
			{ kind = "coins", weight = 35, min = 3, max = 10 },
			{ kind = "pumpkin", weight = 15, min = 1, max = 1 },
			{ kind = "keys", weight = 5, min = 1, max = 1 },
		}, -- ile butelek może wypaść ze śmieci w mieszkaniu (losowo, każda opcja równie często)
		pickupDistance = 10,
		sellDistance = 14,
		-- Event halloweenowy: wystrój kaucjomatu i dynie wypadające przy oddawaniu butelek
-- Rzadkie butelki w trawie między domami: co 45-90 s, najwyżej 3 naraz, znikają po 150 s
		wildInterval = { 45, 90 },
		wildMax = 3,
		wildLifetime = 150,
		halloween = true,
		pumpkinChance = 0.08, -- szansa na dynię za każdą oddaną butelkę
		pumpkinBonus = 5, -- monety za każdą dynię
	},
	-- Prace zmianowe: shift = długość zmiany (s), basePay = wypłata za 2 gwiazdki na poziomie Łatwym,
	-- minShiftTime = szybciej się nie da (ochrona przed oszustwem), levels = cele na 3 gwiazdki dla poziomów 1-3
	cleaner = {
		name = "Sprzątacz",
		unlockMonth = 1,
		implemented = true,
		site = "Office",
		description = "Sprzątaj biuro do końca zmiany: przytrzymaj przycisk przy śmieciach i plamach. Bałaganu ciągle przybywa!",
		shift = 60,
		comboWindow = 7,
		basePay = 34, -- Faza 15: podniesione z 30 (symulacja: czynsz zajmował 67% miesiąca zamiast ~58%)
		minShiftTime = 12,
		visibleItems = 8, -- ile brudu jest naraz w biurze
		levels = { { items = 10 }, { items = 13 }, { items = 16 } },
	},
	gardener = {
		name = "Ogrodnik",
		unlockMonth = 2,
		implemented = true,
		site = "Garden",
		description = "Koś wysoką trawę (wystarczy po niej przejść) i podlewaj zwiędłe kwiatki. Trawa odrasta!",
		shift = 75,
		comboWindow = 4,
		basePay = 51, -- Faza 15: podniesione z 45
		minShiftTime = 20,
		mowRadius = 3.5,
		waterHold = 1.5,
		maxSpeed = 40, -- szybszy ruch = teleport, koszenie się nie liczy
		regrowTime = 6, -- po tylu sekundach skoszona trawa odrasta
		wiltTime = 10, -- po tylu sekundach podlany kwiatek znowu więdnie
		visiblePatches = 14, -- ile kęp trawy jest naraz w ogrodzie
		levels = { { patches = 16, flowers = 4 }, { patches = 22, flowers = 5 }, { patches = 28, flowers = 6 } },
	},
	cashier = {
		name = "Kasjer",
		unlockMonth = 3,
		implemented = true,
		site = "Market",
		description = "Obsłuż jak najwięcej klientów: skanuj ich zakupy i wydawaj poprawną resztę.",
		shift = 60,
		comboWindow = 14,
		basePay = 51, -- Faza 15: podniesione z 46
		minShiftTime = 15,
		minAnswerInterval = 0.35,
		maxDistance = 16, -- odejście od kasy przerywa zmianę
		maxMistakesFor3Stars = 2,
		levels = { { customers = 6, items = 3 }, { customers = 7, items = 4 }, { customers = 8, items = 5 } },
	},
	-- Dowóz kebabów: kebab z okienka budki, rower z parkingu obok, dostawa pod dom, odstawienie roweru
	kebab = {
		name = "Dowóz kebabów",
		unlockMonth = 2,
		implemented = true,
		site = "KebabStand",
		alwaysGuide = true, -- przerywana linia do okienka, roweru, domu i parkingu przy każdej zmianie
		description = "Weź kebab z okienka, wsiądź na rower obok budki i zawieź go pod wskazany dom. Potem wróć, odstaw rower i weź kolejny. Ciepły kebab = lepsza ocena!",
		shift = 110,
		comboWindow = 60, -- dostawa za dostawą bez długich przerw
		basePay = 100,
		minShiftTime = 20,
		walkSpeed = 26, -- rower
		hotTime = 34, -- dostawa w tylu sekundach od wzięcia z okienka = ciepły kebab
		levels = { { deliveries = 3 }, { deliveries = 4 }, { deliveries = 5, far = true } },
	},
	-- Praca w pizzerii (bardziej zaawansowana): minigra robienia pizzy według zamówienia, pakowanie, dowóz skuterem
	pizza = {
		name = "Praca w pizzerii",
		unlockMonth = 4,
		implemented = true,
		site = "Pizzeria",
		alwaysGuide = true, -- przerywana linia do stołu w kuchni, skutera, domu i parkingu przy każdej zmianie
		description = "Zrób pizzę według zamówienia: rozwałkuj ciasto, dodaj sos, ser i składniki, upiecz i zapakuj. Potem zawieź ją skuterem pod wskazany dom i wróć po kolejne zamówienie. Gorąca pizza = lepsza ocena!",
		shift = 150,
		comboWindow = 75,
		basePay = 220,
		minShiftTime = 30,
		walkSpeed = 30, -- skuter
		hotTime = 35, -- dostawa w tylu sekundach od zapakowania = gorąca pizza
		rolls = 5, -- ile razy trzeba rozwałkować ciasto
		minStepInterval = 0.15, -- serwer: szybciej niż co tyle sekund nie da się klikać kroków
		ovenTime = 6, -- pasek pieca (s); wyjęcie w strefie ovenZone (ułamek paska) = idealnie upieczona
		ovenZone = { 0.55, 0.8 },
		maxBadFor3Stars = 1, -- tyle pizz z błędem (zły składnik, surowa, przypalona) wolno przy 3 gwiazdkach
		levels = { { deliveries = 3, toppings = 1 }, { deliveries = 4, toppings = 2 }, { deliveries = 5, toppings = 3, far = true } },
	},
	petsitter = {
		name = "Opiekun zwierząt",
		unlockMonth = 5,
		implemented = true,
		site = "DogHotel",
		alwaysGuide = true, -- przerywana linia do flagi i smaczków przy każdej zmianie (nie tylko pierwszej)
		description = "Wybierz zwierzaka i idź z nim na spacer: flagi, polecenia z pamięci, smaczki i aport!",
		shift = 90,
		comboWindow = 25,
		basePay = 105,
		minShiftTime = 20,
		checkpointRadius = 6,
		maxSpeed = 40,
		revealTime = 2.5, -- ile sekund widać polecenia do zapamiętania
		minAnswerInterval = 0.3,
		-- Zwierzaki do wyboru (modele jak w zoo sklepie)
		pets = {
			{ id = "dog", species = "dog", variant = 1, label = "🐶 Pies Burek" },
			{ id = "dog2", species = "dog", variant = 2, label = "🐕 Pies Łatek" },
			{ id = "cat", species = "cat", variant = 1, label = "🐱 Kot Mruczek" },
			{ id = "rabbit", species = "rabbit", variant = 1, label = "🐰 Królik Uszatek" },
		},
		commands = {
			dog = {
				{ id = "sit", label = "🐕 Siad" },
				{ id = "paw", label = "🐾 Łapa" },
				{ id = "down", label = "💤 Leżeć" },
				{ id = "spin", label = "🌀 Kręć się" },
				{ id = "speak", label = "💬 Głos" },
			},
			cat = {
				{ id = "paw", label = "🐾 Łapka" },
				{ id = "spin", label = "🌀 Kręć się" },
				{ id = "purr", label = "😺 Mrucz" },
				{ id = "jump", label = "🦘 Skok" },
				{ id = "down", label = "💤 Leżeć" },
			},
			rabbit = {
				{ id = "hop", label = "🐇 Hop" },
				{ id = "spin", label = "🌀 Kręć się" },
				{ id = "carrot", label = "🥕 Marchewka" },
				{ id = "ears", label = "👂 Uszy" },
				{ id = "down", label = "💤 Leżeć" },
			},
		},
		-- Minigra "smaczki": zbierz je razem ze zwierzakiem przed końcem czasu
		treats = { dog = "🦴", cat = "🐟", rabbit = "🥕" },
		treatCount = 4,
		treatTime = 25,
		treatRadius = 3.5,
		-- Minigra "aport": trafiony rzut = piłka spada w kółku (tolerancja w studs)
		fetchBands = { near = { 9, 13 }, mid = { 16, 20 }, far = { 24, 28 } },
		fetchTolerance = 3.5,
		-- punkty: flaga = 1, polecenia = 2, wszystkie smaczki = 2 (połowa = 1), trafiony aport = 2
		levels = { { goal = 9, sequence = 2 }, { goal = 12, sequence = 3 }, { goal = 15, sequence = 4 } },
	},
	mechanic = {
		name = "Mechanik",
		unlockMonth = 6,
		implemented = true,
		site = "Garage",
		description = "Znajdź świecące usterki w aucie, przytrzymaj \"Napraw\" i wybierz narzędzie. Koło: klucz, silnik: olej, światło: śrubokręt, wydech: młotek.",
		shift = 90,
		comboWindow = 18,
		basePay = 128,
		minShiftTime = 20,
		repairHold = 1,
		tools = {
			{ id = "wrench", label = "🔧 Klucz" },
			{ id = "oil", label = "💧 Olej" },
			{ id = "screwdriver", label = "🔩 Śrubokręt" },
			{ id = "hammer", label = "🔨 Młotek" },
		},
		parts = {
			wheel = { name = "Koło", tool = "wrench" },
			engine = { name = "Silnik", tool = "oil" },
			light = { name = "Światło", tool = "screwdriver" },
			exhaust = { name = "Wydech", tool = "hammer" },
		},
		levels = { { goal = 6, brokenMax = 2 }, { goal = 8, brokenMax = 3 }, { goal = 10, brokenMax = 4 } },
	},
	freelancer = {
		name = "Freelancer",
		unlockMonth = 7,
		implemented = true,
		site = "Cafe",
		description = "Rozwiązuj szybkie zagadki na komputerze: liczenie, wzory, co nie pasuje i porządkowanie plików.",
		shift = 60,
		comboWindow = 12,
		basePay = 100,
		minShiftTime = 15,
		minAnswerInterval = 0.5,
		maxDistance = 14, -- odejście od komputera przerywa zmianę
		maxMistakesFor3Stars = 2,
		levels = { { goal = 8 }, { goal = 10 }, { goal = 12 } },
	},
	scrapPro = {
		name = "Łowca złomu PRO",
		unlockMonth = 8,
		implemented = true,
		site = "Scrapyard",
		description = "Przeszukuj sterty złomu, napraw znalezisko i sprzedaj je w budce. Cena złomu zmienia się codziennie!",
		shift = 120,
		comboWindow = 35,
		basePay = 240,
		minShiftTime = 30,
		searchHold = 1.5,
		piles = 5,
		priceMin = 0.7, -- cena dnia: od 70% do 130%
		priceMax = 1.3,
		items = {
			{ id = "radio", name = "📻 Radio", fix = "battery" },
			{ id = "bike", name = "🚲 Rower", fix = "chain" },
			{ id = "lamp", name = "💡 Lampa", fix = "bulb" },
			{ id = "toaster", name = "🍞 Toster", fix = "cable" },
		},
		fixes = {
			{ id = "battery", label = "🔋 Bateria" },
			{ id = "chain", label = "⛓ Łańcuch" },
			{ id = "bulb", label = "💡 Żarówka" },
			{ id = "cable", label = "🔌 Kabel" },
		},
		levels = { { goal = 4 }, { goal = 5 }, { goal = 6 } },
	},
}

-- Odblokowanie poziomów: Średni = 5 zmian z co najmniej 2 gwiazdkami, Trudny = 15 zmian, w tym 5 z 3 gwiazdkami
JobsConfig.LevelRequirements = {
	[2] = { good = 5 },
	[3] = { completions = 15, threeStars = 5 },
}

-- Rzadkie zlecenia: pojawiają się same w trakcie miesiąca, nagroda = najlepsza stawka miesiąca x 2.5
JobsConfig.RareContracts = {
	minMonth = 3,
	maxPerMonthEarly = 1,
	maxPerMonthLate = 2,
	lateFromMonth = 6,
	offerWindow = { 60, 280 }, -- sekundy miesiąca, w których może pojawić się zlecenie
	rewardRateMultiplier = 2.5,
	types = {
		cat = { name = "Kot na drzewie", weight = 40, time = 90, hold = 3 },
		party = { name = "Sprzątanie po imprezie", weight = 40, time = 90, trash = 6 },
		goldenCan = { name = "Złota puszka", weight = 20, time = 60, hold = 1.5, tokens = 3, rewardFactor = 0.6, secret = "goldenCan" },
	},
}

-- Produkty w markecie (Kasjer)
JobsConfig.Products = {
	{ id = "apple", name = "Jabłko", emoji = "🍎", price = 3 },
	{ id = "milk", name = "Mleko", emoji = "🥛", price = 4 },
	{ id = "bread", name = "Chleb", emoji = "🍞", price = 5 },
	{ id = "cheese", name = "Ser", emoji = "🧀", price = 7 },
	{ id = "banana", name = "Banan", emoji = "🍌", price = 2 },
	{ id = "egg", name = "Jajka", emoji = "🥚", price = 6 },
	{ id = "chocolate", name = "Czekolada", emoji = "🍫", price = 4 },
	{ id = "carrot", name = "Marchewka", emoji = "🥕", price = 1 },
}

function JobsConfig.GetProduct(id: string)
	for _, product in JobsConfig.Products do
		if product.id == id then
			return product
		end
	end
	return nil
end

return JobsConfig

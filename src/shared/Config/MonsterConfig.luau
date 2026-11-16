-- Potwory: prędkości, zasięgi, czasy. Gracz chodzi 12 i biega 21 (GameConfig).
return {
	CATCH_DISTANCE = 4,
	REPATH_INTERVAL = 0.5, -- co ile sekund pościg liczy nową ścieżkę
	LOSE_SIGHT_TIME = 4, -- po tylu sekundach bez widzenia celu potwór się poddaje

	Neighbor = { -- Cichy Sąsiad, 1. piętro: słyszy bieganie
		patrolSpeed = 7,
		investigateSpeed = 13,
		chaseSpeed = 17,
		hearRadius = 38, -- mnożone przez Cichobiegi gracza
		seeRadius = 14, -- z bliska widzi poruszającego się gracza
		chaseGiveUpRadius = 50,
		lookAroundTime = 3, -- tyle stoi i nasłuchuje w miejscu hałasu
		peekChance = 0.5, -- szansa, że w czasie patrolu zajrzy do mieszkania
	},
	Cat = { -- Mruczek, 2. piętro: idzie za światłem latarki
		wanderSpeed = 6,
		stalkSpeed = 15,
		lightRadius = 45,
		napTime = 6, -- tyle drzemie, zanim znów się przejdzie
		catchDistance = 4.5,
	},
	Landlord = { -- Klucznik o północy
		speed = 17,
		spawnDelay = 3, -- chwila na przemianę, zanim ruszy
	},
}

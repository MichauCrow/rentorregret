-- Jedna lista wszystkich Remote'ów. Serwer tworzy je przy starcie (RemoteService).
return {
	Events = {
		StateUpdate = "StateUpdate", -- serwer -> klient: aktualny stan gracza
		Notify = "Notify", -- serwer -> klient: krótki komunikat
		DebugCommand = "DebugCommand", -- klient -> serwer: komendy testowe (tylko Studio)
		CleanFx = "CleanFx", -- serwer -> klienci: efekt po sprzątnięciu (pozycja, rodzaj, punkty)
		LandlordDialog = "LandlordDialog", -- serwer -> klient: ("open", dane) albo ("close")
		PayRent = "PayRent", -- klient -> serwer: "Zapłać" w oknie właściciela
		PayDebt = "PayDebt", -- klient -> serwer: spłata długu przyciskiem w HUD
		OpenJobMenu = "OpenJobMenu", -- serwer -> klient: menu wyboru poziomu pracy
		StartJob = "StartJob", -- klient -> serwer: (jobId, poziom)
		CancelJob = "CancelJob", -- klient -> serwer: przerwanie zmiany
		JobAction = "JobAction", -- klient -> serwer: akcja w minigrze (np. kasjer)
		JobUpdate = "JobUpdate", -- serwer -> klient: postęp zmiany
		JobResult = "JobResult", -- serwer -> klient: gwiazdki i wypłata
		GoHome = "GoHome", -- klient -> serwer: przycisk "DOM" (teleport do mieszkania)
		SocialAction = "SocialAction", -- klient -> serwer: zaproszenia, wyprowadzka, drzwi otwarte
		SocialState = "SocialState", -- serwer -> klient: stan ekipy
		SocialInvite = "SocialInvite", -- serwer -> klient: zaproszenie do wspólnego mieszkania
		ProgressUpdate = "ProgressUpdate", -- serwer -> klient: zmieniły się zadania/osiągnięcia (odśwież panel)
		TutorialAction = "TutorialAction", -- klient -> serwer: "skip" (pomiń samouczek)
		RepairGame = "RepairGame", -- serwer -> klient: ("open", dane) / ("close", wynik) minigry naprawy awarii
		RepairAction = "RepairAction", -- klient -> serwer: (failureId, "hit" | "cancel") w minigrze naprawy
		FurniturePlace = "FurniturePlace", -- serwer -> klient: rozpocznij ustawianie mebla (dane mieszkania i mebla)
		TrashGame = "TrashGame", -- serwer -> klient: ("open", dane) / ("result", nagroda) minigry przeszukiwania kosza
		TrashAction = "TrashAction", -- klient -> serwer: "done" (koniec szukania) albo "cancel"
		FurnitureAction = "FurnitureAction", -- klient -> serwer: (index, "place", x, z, obrót) albo (index, "cancel")
		PetAction = "PetAction", -- klient -> serwer: (petId, polecenie, [siła rzutu przy aporcie])
		RentalAction = "RentalAction", -- klient -> serwer: ("start", nr stacji) / ("stop") / ("wheelie", bool)
		RentalState = "RentalState", -- serwer -> klient: ("start", dane jazdy) / ("tick", zapłacono) / ("stop", powód)
		BuildGame = "BuildGame", -- serwer -> klient: ("open", dane etapu) / ("close", wynik) minigry budowy pokoju
		BuildAction = "BuildAction", -- klient -> serwer: "hit" | "cancel" w minigrze budowy
		JobUnlocked = "JobUnlocked", -- serwer -> klient: { jobId, ... } nowe prace w tym miesiącu (cut scena z drona)
		XpGain = "XpGain", -- serwer -> klient: { amount, reason, level, xp, need, ups } zdobyte XP i nowe poziomy
	},
	Functions = {
		GetState = "GetState", -- klient pyta o stan przy starcie
		GetShop = "GetShop", -- klient pobiera katalog sklepu
		BuyItem = "BuyItem", -- klient kupuje przedmiot (odpowiedź: wynik + nowy katalog)
		GetSocial = "GetSocial", -- klient pobiera stan ekipy
		GetProgress = "GetProgress", -- kalendarz, zadania, wyzwania, osiągnięcia
		ClaimDaily = "ClaimDaily", -- odbiór nagrody dnia
		GetLeaderboard = "GetLeaderboard", -- rankingi tygodniowe
		CosmeticAction = "CosmeticAction", -- ("buy"|"equip"|"unequip", id) -> wynik + nowa lista kosmetyków
		GetPets = "GetPets", -- katalog sklepu zoologicznego i własne zwierzaki
		BuyPet = "BuyPet", -- (gatunek) -> wynik + nowy katalog
		HomeAction = "HomeAction", -- ("get") / ("paint", pokój, kolor, wykończenie) / ("build", nr pokoju) -> wynik + stan domu
		Wheel = "Wheel", -- ("get") -> stan koła nagród / ("spin") -> { ok, index, label, state }
		Gifts = "Gifts", -- ("get") -> prezenty za czas gry / ("claim", nr) / ("claimAll") -> { ok, claimed, state }
		RedeemCode = "RedeemCode", -- (tekst kodu) -> { ok, message, rewards }
	},
}

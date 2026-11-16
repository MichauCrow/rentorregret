-- Dźwięki. Gra działa bez nich (pusty tekst = brak dźwięku).
-- Aby dodać dźwięk: w Studio otwórz Toolbox -> Audio, wyszukaj (np. "clock tick", "cat purr"), kliknij
-- prawym -> Copy Asset ID i wpisz tu "rbxassetid://ID". Po uruchomieniu testu w Studio w oknie Output
-- pojawi się raport "[Dźwięki]" z informacją, które dźwięki się wczytują.
return {
	Sounds = {
		-- Sprawdzone w Studio w poprzedniej wersji gry
		UIClick = "rbxassetid://9119730203", -- Switch Click (ProSoundEffects)
		Coins = "rbxassetid://9113848518", -- Coin Toss (ProSoundEffects)
		Success = "rbxassetid://1839881844", -- Spinning Around (b), APM
		RentPaid = "rbxassetid://1839982934", -- J Funk (sting), APM
		Doorbell = "rbxassetid://1840084286", -- Musical Doorbell (d), APM
		Warning = "rbxassetid://9113085623", -- Alarm Buzzer (ProSoundEffects)
		-- Wbudowane w Roblox (pliki klienta, nie trzeba ich wgrywać)
		NeighborSteps = "rbxasset://sounds/action_footsteps_plastic.mp3", -- kroki Sąsiada (spowolnione)
		LandlordSteps = "rbxasset://sounds/action_footsteps_plastic.mp3", -- kroki Klucznika (niższe)
		-- Do wybrania w Toolboxie (patrz opis na górze):
		Caught = "", -- zabawne "buu!" przy złapaniu
		Midnight = "", -- bicie zegara o północy
		ClockTick = "", -- tykanie zegara w ostatniej minucie
		Heartbeat = "", -- bicie serca, gdy potwór goni
		Purr = "", -- mruczenie Mruczka (pętla)
		Keys = "", -- brzęk kluczy Klucznika (pętla)
		AmbientNight = "", -- cichy szum nocy w kamienicy (pętla)
		Search = "", -- szuranie przy przeszukiwaniu
	},
	-- Muzyka tylko w holu (w kamienicy cisza i odgłosy)
	Music = {
		"rbxassetid://1842214009", -- Plenty Funny (APM)
	},
	Volumes = {
		UIClick = 0.35,
		Coins = 0.5,
		Success = 0.18,
		RentPaid = 0.55,
		Doorbell = 0.7,
		Warning = 0.25,
		Caught = 0.6,
		Midnight = 0.7,
		ClockTick = 0.35,
		Heartbeat = 0.6,
		NeighborSteps = 0.8,
		LandlordSteps = 1,
		Purr = 0.7,
		Keys = 0.6,
		AmbientNight = 0.3,
		Search = 0.4,
		Music = 0.18,
	},
	-- Prędkość odtwarzania (wysokość dźwięku)
	Pitch = {
		NeighborSteps = 0.75,
		LandlordSteps = 0.55,
	},
	SoundMaxLength = {
		Success = 2.5,
		RentPaid = 3,
		Warning = 0.6,
	},
}

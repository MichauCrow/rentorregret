-- Placeholdery na dźwięki i tekstury. Gra działa bez nich.
-- Aby dodać dźwięk: wgraj go w Creator Hub albo wybierz z Toolboxa i wpisz "rbxassetid://TWOJE_ID".
-- Nie wpisuj ID, których nie sprawdziłeś w Studio.
return {
	-- Sprawdzone w Studio (wczytują się). Pusty tekst = brak dźwięku.
	Sounds = {
		CleanTrash = "rbxassetid://9120258592", -- Trash Movement 1 (ProSoundEffects)
		CleanStain = "rbxassetid://9113781690", -- Chalkboard Erasing (ProSoundEffects); zapas: 76423296618759 "glass wipe polish"
		CleanDishes = "rbxassetid://9120969588", -- Wood Utensils 9 (ProSoundEffects)
		AllClean = "rbxassetid://139651791574775", -- Aquapark SFX - finish; zapas: 4612374036 "bling_big_diamond_pickup"
		-- Interfejs (Faza 13)
		UIClick = "rbxassetid://9119730203", -- Switch Click (ProSoundEffects)
		Coins = "rbxassetid://9113848518", -- Coin Toss (ProSoundEffects)
		Success = "rbxassetid://1839881844", -- Spinning Around (b), APM
		RentPaid = "rbxassetid://1839982934", -- J Funk (sting), APM
		Doorbell = "rbxassetid://1840084286", -- Musical Doorbell (d), APM
		Warning = "rbxassetid://9113085623", -- Alarm Buzzer (ProSoundEffects), cicho i krótko
		-- Prace (sprawdzone w Studio: PreloadAsync = Success)
		ScooterEngine = "rbxassetid://2751122980", -- silnik na biegu jałowym (pętla 0,5 s)
		Mower = "rbxassetid://6760745860", -- silnik spalinowy kosiarki (pętla)
		DogBark = "rbxassetid://348993071", -- jedno krótkie szczeknięcie (sprawdzone: gra w Play bez błędu uprawnień)
	},
	-- Muzyka w tle (biblioteka APM, licencjonowana przez Roblox), grana na zmianę
	Music = {
		"rbxassetid://1842214009", -- Plenty Funny
		"rbxassetid://1835450977", -- Funny Country
	},
	Volumes = {
		UIClick = 0.35,
		Coins = 0.5,
		Success = 0.18, -- cicho: gra przy końcu zmiany, celu i kaucjomacie
		RentPaid = 0.55,
		Doorbell = 0.7,
		Warning = 0.25,
		ScooterEngine = 0.35,
		DogBark = 0.8,
		Mower = 0.4,
		Music = 0.22,
	},
	-- Po ilu sekundach dźwięk ma się wyciszyć (brak wpisu = gra do końca)
	SoundMaxLength = {
		CleanTrash = 1.2,
		CleanStain = 1.5,
		CleanDishes = 1.2,
		Success = 2.5,
		RentPaid = 3,
		Warning = 0.6,
	},
	Textures = {
		Sparkle = "rbxasset://textures/particles/sparkles_main.dds", -- wbudowana tekstura Roblox
	},
}

-- Dźwięki. Gra działa bez nich (pusty tekst = brak dźwięku).
-- Aby dodać dźwięk: wybierz go z Toolboxa (Audio) albo wgraj w Creator Hub i wpisz "rbxassetid://TWOJE_ID".
-- Nie wpisuj ID, których nie sprawdziłeś w Studio.
return {
	-- Sprawdzone w Studio w poprzedniej wersji gry
	Sounds = {
		UIClick = "rbxassetid://9119730203", -- Switch Click (ProSoundEffects)
		Coins = "rbxassetid://9113848518", -- Coin Toss (ProSoundEffects)
		Success = "rbxassetid://1839881844", -- Spinning Around (b), APM
		RentPaid = "rbxassetid://1839982934", -- J Funk (sting), APM
		Doorbell = "rbxassetid://1840084286", -- Musical Doorbell (d), APM
		Warning = "rbxassetid://9113085623", -- Alarm Buzzer (ProSoundEffects)
		-- Do uzupełnienia w Fazie 2 (sprawdź w Studio i wpisz ID):
		Caught = "", -- zabawne "buu!" przy złapaniu
		Midnight = "", -- bicie zegara o północy
		Purr = "", -- mruczenie Mruczka
		Footsteps = "", -- skrzypienie podłogi
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
		Music = 0.18,
	},
	SoundMaxLength = {
		Success = 2.5,
		RentPaid = 3,
		Warning = 0.6,
	},
}

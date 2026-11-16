-- Jedna lista wszystkich Remote'ów. Serwer tworzy je przy starcie (RemoteService).
return {
	Events = {
		StateUpdate = "StateUpdate", -- serwer -> klient: zapisany stan gracza (monety, ulepszenia, ustawienia)
		Notify = "Notify", -- serwer -> klient: (tekst, rodzaj "info" | "good" | "warn" | "bad")
		RoundState = "RoundState", -- serwer -> klient: stan rundy do HUD (albo nil = gracz w holu)
		RoundEvent = "RoundEvent", -- serwer -> klient: (rodzaj, dane): "start", "caught", "alert", "midnight", "paid", "ping", "end"
		Flashlight = "Flashlight", -- klient -> serwer: (włączona: bool)
		GhostPing = "GhostPing", -- klient -> serwer: duszek wskazuje drużynie najbliższe monety
		SetSetting = "SetSetting", -- klient -> serwer: (klucz, wartość)
		DebugCommand = "DebugCommand", -- klient -> serwer: komendy testowe (tylko Studio)
	},
	Functions = {
		GetState = "GetState", -- klient pyta o stan przy starcie
		BuyUpgrade = "BuyUpgrade", -- (id ulepszenia) -> { ok, message, state }
	},
}

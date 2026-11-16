-- Ulepszenia w sklepiku w holu. Poziom 1 = to, z czym gracz zaczyna (cost = 0).
-- value: wartość działająca w grze na danym poziomie.
return {
	Order = { "flashlight", "shoes", "pockets", "stamina" },
	Upgrades = {
		flashlight = {
			name = "Latarka",
			icon = "🔦",
			description = "Większa bateria i dalszy zasięg światła.",
			levels = {
				{ cost = 0, value = { battery = 60, range = 40 } },
				{ cost = 150, value = { battery = 100, range = 50 } },
				{ cost = 450, value = { battery = 160, range = 60 } },
			},
		},
		shoes = {
			name = "Cichobiegi",
			icon = "👟",
			description = "Cichy Sąsiad słyszy Twój bieg z mniejszej odległości.",
			levels = {
				{ cost = 0, value = 1 },
				{ cost = 200, value = 0.7 },
				{ cost = 550, value = 0.45 },
			},
		},
		pockets = {
			name = "Kieszenie",
			icon = "🎒",
			description = "Unosisz więcej monet naraz.",
			levels = {
				{ cost = 0, value = 50 },
				{ cost = 120, value = 90 },
				{ cost = 400, value = 150 },
			},
		},
		stamina = {
			name = "Kondycja",
			icon = "💪",
			description = "Dłuższy sprint.",
			levels = {
				{ cost = 0, value = 1 },
				{ cost = 180, value = 1.5 },
				{ cost = 500, value = 2 },
			},
		},
	},
}

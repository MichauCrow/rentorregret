-- Zwierzaki ze sklepu zoologicznego. Tylko zabawa i wygląd (bez przewagi w grze).
-- max = ile sztuk danego gatunku można mieć (psy i koty po 2, reszta po 1).
-- follow = chodzi za graczem (pies na smyczy), flying = lata przy ramieniu, cage = mieszka w klatce w domu.
local PetConfig = {}

PetConfig.Species = {
	dog = { name = "Pies", emoji = "🐶", price = 400, max = 2, follow = true, leash = true, commands = { "paw", "fetch", "spin", "speak", "stay" },
		names = { "Burek", "Azor", "Reksio", "Łatek", "Max", "Fafik" }, say = "Hau! Hau! 🐶" },
	cat = { name = "Kot", emoji = "🐱", price = 350, max = 2, follow = true, commands = { "spin", "speak", "stay" },
		names = { "Mruczek", "Filemon", "Puszek", "Luna", "Kicia", "Tygrys" }, say = "Miau! 🐱" },
	rabbit = { name = "Królik", emoji = "🐰", price = 250, max = 1, follow = true, commands = { "hop", "spin", "stay" },
		names = { "Uszatek", "Kicek", "Śnieżka", "Bobik" }, say = "*kic kic* 🐰" },
	hamster = { name = "Chomik z klatką", emoji = "🐹", price = 150, max = 1, follow = false, cage = true, commands = { "wheel", "speak" },
		names = { "Pysio", "Okruszek", "Fistaszek", "Ziarenko" }, say = "Pi pi! 🐹" },
	parrot = { name = "Papuga", emoji = "🦜", price = 300, max = 1, follow = true, flying = true, commands = { "speak", "spin", "stay" },
		names = { "Kubuś", "Kiwi", "Rio", "Koko" }, say = "Cześć! Cześć! 🦜" },
}

PetConfig.Order = { "dog", "cat", "rabbit", "hamster", "parrot" }

PetConfig.Commands = {
	paw = { label = "🐾 Daj łapę" },
	fetch = { label = "🎾 Aport" },
	spin = { label = "🌀 Obrót" },
	speak = { label = "💬 Daj głos" },
	hop = { label = "🐇 Skok" },
	wheel = { label = "🎡 Kółko" },
	stay = { label = "🏠 Zostań w domu", alt = "🚶 Chodź ze mną" },
}

return PetConfig

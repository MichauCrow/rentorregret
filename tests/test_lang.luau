-- Pokrycie tłumaczeń: każdy polski tekst widoczny dla gracza musi mieć wersję angielską.
-- 1) teksty złożone w kodzie (z liczbami, imionami), 2) wszystkie stałe teksty z kodu z polskimi znakami.
local fs = require("@lune/fs")
local H = require("./harness")
local Lang = H.load(H.root .. "/shared/Modules/Lang")

local samples = {
	"🚪 Wchodzicie: 2/4  •  start za 9 s",
	"Pan Klucznik 🙂",
	"Pan Klucznik 😊",
	"Łóżko (zostało 12)",
	"🔦 Latarka: poziom 2!",
	"💪 Kondycja: poziom 3!",
	"👻 Ala został złapany i jest teraz duszkiem!",
	"🔓 Olek123 otworzył zamknięte mieszkanie!",
	"🏃 Zosia wyszedł z kamienicy.",
	"👻 Ala wskazuje: Komoda (świeci na niebiesko)",
	"🎒 Kieszenie pełne! W słoiku zostało 40.",
	"💰 Czynsz: 1 234 / 2 000",
	"🏃 UCIEKAJ! 1:05",
	"📍 Parter",
	"📍 2. piętro",
	"🎯 🔍 Szukaj dalej albo zanieś monety do BIURA (🎒 30).",
	"🎯 💰 Wpłać jeszcze 25 (premia x1.5) albo uciekaj do bramy!",
	"🕗 Masz czas do północy, żeby uzbierać 190 💰 czynszu!",
	"Czynsz zapłacony w 3:12 🎉",
	"Drużyna wpłaciła: 200 / 190 💰",
	"Ty znalazłeś: 87 💰, wpłaciłeś: 80 💰",
	"NAGRODA: +252 💰",
	"Wpłacono 45 💰",
	"Poziom 2/3",
	"KUP: 1 500 💰",
	"PIĘTRO 2",
	"F: latarka   Shift: bieg   E: szukaj",
	"Cichy Sąsiad Cię usłyszał i odprowadził do łóżka!\n👻 Jesteś teraz duszkiem.",
	"JAK GRAĆ\n🔍 Przeszukuj meble i zbieraj monety\n💰 Zanieś je do skrzynki Klucznika\n🕛 Zapłać czynsz przed północą!\n🤫 Sąsiad słyszy bieganie\n🔦 Mruczek idzie za światłem\n🚪 Chowaj się w szafach",
}

-- Teksty, których gracz nie widzi albo które są fragmentami składanych zdań
local IGNORE = {
	"^%[", "^ ", " $", "^%.", "^:", "AssetsConfig", "raport", "Muzyka ", "serwer", "puszkę", "myśli", "ściany", "^load", "^save",
	"Nieznan", "wczytuje się", "^Wpłać jeszcze", "^Szukaj dalej", "^PIĘTRO $", "^KUP: $", "^Pan Klucznik $", "UCIEKAJ! $",
	"Twoje dane", "Nie udało się wczytać", "%%s", "^Wpłacono $", "dane gracza", "clock tick", "Jak grać",
}

local POLISH_LETTERS = { "ą", "ć", "ę", "ł", "ń", "ó", "ś", "ź", "ż", "Ą", "Ć", "Ę", "Ł", "Ń", "Ó", "Ś", "Ź", "Ż" }
local function hasPolish(text: string): boolean
	for _, letter in POLISH_LETTERS do
		if text:find(letter, 1, true) then
			return true
		end
	end
	return false
end
local POLISH_WORDS = { "Przeszukaj", "Komoda", "Szafa", "Parter", "Pusto", "Pudła", "Latarka", "Kieszenie", "Kondycja", "Cichobiegi", "KUP", "BIURO", "Wyjdź", "Podnieś" }

local missing = {}
local function check(text: string, origin: string)
	local translated = Lang.ToEnglish(text)
	local polishLeft = hasPolish(translated)
	if not polishLeft then
		for _, word in POLISH_WORDS do
			if translated:find(word, 1, true) then
				polishLeft = true
			end
		end
	end
	if polishLeft then
		table.insert(missing, origin .. ": " .. text .. "  ->  " .. translated)
	end
end

for _, text in samples do
	check(text, "próbka")
end

local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.luau$") and not name:match("Entries") and not name:match("^init") then
			for line in fs.readFile(path):gmatch("[^\n]+") do
				local code = line:gsub("^%s*%-%-.*$", "")
				for text in code:gmatch('"([^"]*)"') do
					local skip = not hasPolish(text) and not table.find(POLISH_WORDS, text)
					for _, pattern in IGNORE do
						if text:find(pattern) then
							skip = true
						end
					end
					if not skip then
						check((text:gsub("\\n", "\n")), name)
					end
				end
			end
		end
	end
end
walk(H.root)

if #missing > 0 then
	print("BRAK TŁUMACZEŃ (" .. #missing .. "):")
	for _, line in missing do
		print("  " .. line)
	end
	error("niepełne tłumaczenie")
end
print("Przykład: " .. Lang.ToEnglish("👻 Ala wskazuje: Komoda (świeci na niebiesko)"))
print("Przykład: " .. Lang.ToEnglish("🎯 🔍 Szukaj dalej albo zanieś monety do BIURA (🎒 30)."))
print("TŁUMACZENIA KOMPLETNE")

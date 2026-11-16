-- Tłumacz tekstów gry PL -> EN, używany przez klienta przy wyświetlaniu (LanguageController).
-- Gra w całości pisze po polsku; tu jest słownik i dopasowanie tekstów z liczbami i nazwami.
-- Wpisy w Lang.ENTRIES: { "tekst PL", "tekst EN" }. W tekście PL:
--   %d = dowolna liczba (też "1 234"), %s = dowolny fragment (np. nazwa pracy, imię gracza),
--   %% = znak procentu. Fragmenty %s są tłumaczone osobno (rekurencyjnie).
-- Odmiana: moneta/monety/monet, butelkę/butelki/butelek, klucz/klucze/kluczy, dynia/dynie/dyń
-- są traktowane jako jedno słowo, więc wystarczy jeden wpis (np. z "monet").
local Entries = require(script:WaitForChild("Entries"))

local Lang = {}

local PLURALS = {
	{ "moneta", "monet" }, { "monety", "monet" },
	{ "butelkę", "butelek" }, { "butelki", "butelek" },
	{ "klucz", "kluczy" }, { "klucze", "kluczy" },
	{ "dynia", "dyń" }, { "dynie", "dyń" },
}
local EN_SINGULAR = { "coin", "bottle", "key", "pumpkin", "shift", "month", "item", "thing", "day", "customer", "screw", "time" }
local THOUSANDS = "\1"
local CAPTURE = "\3"
local PERCENT = "\2"

local exact = {}
local patterns = {}
local cache = {}
local cacheSize = 0

-- Zamienia całe słowa w odmianie na jedną formę (granice słowa: wszystko poza literami, też polskimi)
local function canon(text: string): string
	local padded = " " .. text .. " "
	for _, pair in PLURALS do
		padded = padded:gsub("([^%w\128-\255])" .. pair[1] .. "([^%w\128-\255])", "%1" .. pair[2] .. "%2")
		padded = padded:gsub("([^%w\128-\255])" .. pair[1] .. "([^%w\128-\255])", "%1" .. pair[2] .. "%2")
	end
	return padded:sub(2, -2)
end

-- Liczby -> "#", a ich wartości trafiają do listy (separator tysięcy "1 234" = jedna liczba)
local function extractNumbers(text: string, numbers): string
	local joined = text
	for _ = 1, 4 do
		joined = joined:gsub("(%d) (%d%d%d)%f[%D]", "%1" .. THOUSANDS .. "%2")
	end
	return (joined:gsub("[%d" .. THOUSANDS .. "]+", function(number)
		table.insert(numbers, (number:gsub(THOUSANDS, " ")))
		return "#"
	end))
end

local function escapePattern(text: string): string
	return (text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
end

local function prepare(pl: string, en: string)
	local key = pl:gsub("%%%%", PERCENT):gsub("%%d", "#"):gsub("%%s", CAPTURE)
	-- Liczby wpisane wprost w tekście PL (np. "Opłać 1 miesiąc") też zamieniamy na "#", jak w grze
	key = canon(extractNumbers(key, {}))
	local value = en:gsub("%%%%", PERCENT):gsub("%%d", "#")
	if key:find(CAPTURE, 1, true) then
		local pattern = escapePattern(key):gsub(CAPTURE, "(.-)"):gsub(PERCENT, "%%%%")
		local parts = string.split((value:gsub(PERCENT, "%%")), "%s")
		table.insert(patterns, { pattern = "^" .. pattern .. "$", parts = parts })
	else
		exact[(key:gsub(PERCENT, "%%"))] = (value:gsub(PERCENT, "%%"))
	end
end

for _, entry in Entries do
	prepare(entry[1], entry[2])
end

local translateNormalized

-- Tekst bez liczb (z "#") -> tłumaczenie albo nil
translateNormalized = function(text: string, depth: number): string?
	if text == "" then
		return ""
	end
	local found = exact[text]
	if found then
		return found
	end
	if depth > 4 then
		return nil
	end
	for _, entry in patterns do
		local captures = { text:match(entry.pattern) }
		-- Fragment %s nie może obejmować kilku zdań (wtedy tłumaczymy zdanie po zdaniu niżej)
		local spansSentences = false
		for _, captured in captures do
			if captured:find("[%.!%?]%s") then
				spansSentences = true
			end
		end
		if #captures > 0 and not spansSentences then
			local out = entry.parts[1]
			for i = 2, #entry.parts do
				local captured = captures[i - 1] or ""
				out ..= (translateNormalized(captured, depth + 1) or captured) .. entry.parts[i]
			end
			return out
		end
	end
	-- Kilka zdań albo segmentów rozdzielonych szerokimi odstępami: tłumaczymy każdy osobno
	for _, separator in { "   ", "  ·  ", " · ", "  →  " } do
		if text:find(separator, 1, true) then
			local pieces = string.split(text, separator)
			local any = false
			for i, piece in pieces do
				local translated = translateNormalized(piece, depth + 1)
				if translated then
					pieces[i] = translated
					any = true
				end
			end
			if any then
				return table.concat(pieces, separator)
			end
		end
	end
	-- Podział na zdania (ostatni kawałek może nie mieć kropki, np. "... w zastaw: Fotel")
	local sentences = {}
	local rest = text
	while true do
		local _, finish = rest:find("[%.!%?]+%s+")
		if not finish then
			break
		end
		table.insert(sentences, (rest:sub(1, finish):gsub("%s+$", "")))
		rest = rest:sub(finish + 1)
	end
	if rest ~= "" then
		table.insert(sentences, rest)
	end
	if #sentences > 1 then
		-- Najpierw najdłuższe grupy zdań ze słownika (wpis może mieć dwa zdania), potem pojedyncze
		local result = {}
		local any = false
		local i = 1
		while i <= #sentences do
			local matched = false
			for j = #sentences, i + 1, -1 do
				local group = table.concat(sentences, " ", i, j)
				if exact[group] then
					table.insert(result, exact[group])
					any = true
					matched = true
					i = j + 1
					break
				end
			end
			if not matched then
				local translated = translateNormalized(sentences[i], depth + 1)
				if translated then
					any = true
				end
				table.insert(result, translated or sentences[i])
				i += 1
			end
		end
		if any then
			return table.concat(result, " ")
		end
	end
	-- Emoji na początku (np. "🌿 Roślinka"): tłumaczymy resztę i doklejamy emoji
	local first, rest = text:match("^(%S+)%s+(.+)$")
	if first and not first:find("%a") and not first:find("#") then
		local translatedRest = translateNormalized(rest, depth + 1)
		if translatedRest then
			return first .. " " .. translatedRest
		end
	end
	return nil
end

local function translateLine(line: string): string
	if not line:find("%a") and not line:find("[\128-\255]") then
		return line
	end
	local numbers = {}
	local normalized = canon(extractNumbers(line, numbers))
	local translated = translateNormalized(normalized, 0)
	if not translated then
		return line
	end
	local index = 0
	translated = translated:gsub("#", function()
		index += 1
		return numbers[index] or "?"
	end)
	for _, noun in EN_SINGULAR do
		translated = translated:gsub("%f[%d]1 " .. noun .. "s%f[%A]", "1 " .. noun)
	end
	return translated
end

-- Główne wejście: tekst PL -> EN (tekst bez tłumaczenia wraca bez zmian)
function Lang.ToEnglish(text: string): string
	local hit = cache[text]
	if hit then
		return hit
	end
	local lines = string.split(text, "\n")
	for i, line in lines do
		lines[i] = translateLine(line)
	end
	local result = table.concat(lines, "\n")
	if cacheSize > 3000 then
		cache = {}
		cacheSize = 0
	end
	cache[text] = result
	cacheSize += 1
	return result
end

return Lang

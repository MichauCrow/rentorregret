-- Formatowanie liczb i czasu do wyświetlania w interfejsie
local Format = {}

-- 12345 -> "12 345"
function Format.Number(value: number): string
	local digits = tostring(math.floor(math.abs(value)))
	local grouped = string.reverse(digits)
	grouped = string.gsub(grouped, "(%d%d%d)", "%1 ")
	grouped = string.reverse(grouped)
	grouped = string.gsub(grouped, "^ ", "")
	if value < 0 then
		return "-" .. grouped
	end
	return grouped
end

-- Polska odmiana: Format.Plural(2, "puszkę", "puszki", "puszek") -> "puszki"
function Format.Plural(count: number, one: string, few: string, many: string): string
	local n = math.abs(math.floor(count))
	if n == 1 then
		return one
	end
	local lastDigit = n % 10
	local lastTwo = n % 100
	if lastDigit >= 2 and lastDigit <= 4 and (lastTwo < 12 or lastTwo > 14) then
		return few
	end
	return many
end

-- 125 -> "2:05"
function Format.Time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

return Format

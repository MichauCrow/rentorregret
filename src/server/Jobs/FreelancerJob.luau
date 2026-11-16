-- Freelancer: zagadki na komputerze. Serwer losuje zadanie i zna odpowiedź;
-- klient wysyła tylko wybraną odpowiedź. Odejście od komputera przerywa zmianę.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local JobService = require(Services.JobService)

local FreelancerJob = {
	JobId = "freelancer",
}

local CONFIG = JobsConfig.Jobs.freelancer
local PATTERN_SETS = { { "🔴", "🔵", "⭐" }, { "🍎", "🍌", "🍇" }, { "🐶", "🐱", "🐭" }, { "☀️", "🌙", "☁️" } }
local CATEGORIES = {
	{ "🍎", "🍌", "🍇", "🍐" },
	{ "🐶", "🐱", "🐭", "🐰" },
	{ "🚗", "🚌", "🚲", "🚂" },
	{ "⚽", "🏀", "🎾", "🏐" },
}
local FILES = {
	{ "kot.png", "📁 Obrazki" },
	{ "wakacje.jpg", "📁 Obrazki" },
	{ "piosenka.mp3", "📁 Muzyka" },
	{ "dzwonek.wav", "📁 Muzyka" },
	{ "zadanie.txt", "📁 Dokumenty" },
	{ "list.doc", "📁 Dokumenty" },
	{ "film.mp4", "📁 Filmy" },
	{ "bajka.avi", "📁 Filmy" },
}
local FOLDERS = { "📁 Obrazki", "📁 Muzyka", "📁 Dokumenty", "📁 Filmy" }
local TYPES = { "math", "pattern", "odd", "file" }

local desk = nil
local rng = Random.new()

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Każdy generator zwraca { question, options = { tekst, ... }, answer = tekst }
local generators = {}

function generators.math(level: number)
	local question, answer
	if level == 1 then
		local a, b = rng:NextInteger(1, 10), rng:NextInteger(1, 10)
		question, answer = string.format("%d + %d = ?", a, b), a + b
	elseif level == 2 then
		local a, b = rng:NextInteger(5, 20), rng:NextInteger(1, 10)
		if rng:NextInteger(1, 2) == 1 then
			question, answer = string.format("%d + %d = ?", a, b), a + b
		else
			question, answer = string.format("%d - %d = ?", a, b), a - b
		end
	else
		local a, b = rng:NextInteger(2, 9), rng:NextInteger(2, 9)
		question, answer = string.format("%d × %d = ?", a, b), a * b
	end
	local options = { tostring(answer) }
	local used = { [answer] = true }
	while #options < 4 do
		local wrong = answer + rng:NextInteger(-5, 5)
		if wrong >= 0 and not used[wrong] then
			used[wrong] = true
			table.insert(options, tostring(wrong))
		end
	end
	return { question = question, options = shuffle(options), answer = tostring(answer) }
end

function generators.pattern(level: number)
	local set = PATTERN_SETS[rng:NextInteger(1, #PATTERN_SETS)]
	local units = { { 1, 2 }, { 1, 1, 2 } }
	if level >= 2 then
		table.insert(units, { 1, 2, 3 })
	end
	if level >= 3 then
		table.insert(units, { 1, 2, 2, 3 })
	end
	local unit = units[rng:NextInteger(1, #units)]
	local length = #unit + rng:NextInteger(2, 3)
	local shown = {}
	for i = 1, length do
		shown[i] = set[unit[(i - 1) % #unit + 1]]
	end
	local answer = set[unit[length % #unit + 1]]
	return {
		question = "Co będzie dalej?  " .. table.concat(shown, " ") .. " ❓",
		options = shuffle({ set[1], set[2], set[3] }),
		answer = answer,
	}
end

function generators.odd()
	local first = rng:NextInteger(1, #CATEGORIES)
	local second = rng:NextInteger(1, #CATEGORIES - 1)
	if second >= first then
		second += 1
	end
	local pool = shuffle(table.clone(CATEGORIES[first]))
	local odd = CATEGORIES[second][rng:NextInteger(1, 4)]
	return {
		question = "Co nie pasuje do reszty?",
		options = shuffle({ pool[1], pool[2], pool[3], odd }),
		answer = odd,
	}
end

function generators.file()
	local file = FILES[rng:NextInteger(1, #FILES)]
	return {
		question = "Do którego folderu zapisać plik " .. file[1] .. "?",
		options = shuffle(table.clone(FOLDERS)),
		answer = file[2],
	}
end

local function nextPuzzle(session, mistake: boolean)
	local state = session.state
	local kind
	repeat
		kind = TYPES[rng:NextInteger(1, #TYPES)]
	until kind ~= state.lastKind
	state.lastKind = kind
	local puzzle = generators[kind](session.level)
	state.answer = puzzle.answer
	state.number += 1
	local options = {}
	for _, text in puzzle.options do
		table.insert(options, { value = text, label = text })
	end
	JobService.UpdateProgress(session, state.solved, state.goal, "Rozwiązuj zadania na komputerze", {
		mode = "choice",
		action = "answer",
		title = (if mistake then "❌ Zła odpowiedź. " else "") .. "Zadanie nr " .. state.number,
		prompt = puzzle.question,
		options = options,
	})
end

function FreelancerJob.Init()
	desk = Workspace.Map.JobSites:WaitForChild("Cafe"):WaitForChild("StartPart")
end

function FreelancerJob.StartShift(session)
	local state = session.state
	state.goal = session.levelConfig.goal
	state.solved = 0
	state.mistakes = 0
	state.number = 0
	state.lastAnswer = 0
	nextPuzzle(session, false)
end

function FreelancerJob.OnAction(session, action: string, value: any)
	local state = session.state
	if action ~= "answer" or not RemoteService.IsString(value, 64) then
		return
	end
	local now = os.clock()
	if now - state.lastAnswer < CONFIG.minAnswerInterval then
		return
	end
	state.lastAnswer = now
	if value == state.answer then
		state.solved += 1
		nextPuzzle(session, false)
	else
		state.mistakes += 1
		nextPuzzle(session, true)
	end
end

function FreelancerJob.TickShift(session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - desk.Position).Magnitude > CONFIG.maxDistance then
		JobService.Cancel(session.player, "Za daleko od komputera. Zmiana przerwana.")
	end
end

-- 3 gwiazdki: cel osiągnięty i najwyżej maxMistakesFor3Stars pomyłek
function FreelancerJob.Evaluate(session): number
	local state = session.state
	local fraction = state.solved / state.goal
	if fraction >= 1 and state.mistakes <= CONFIG.maxMistakesFor3Stars then
		return 3
	end
	return math.min(2, JobService.StarsFromFraction(fraction))
end

return FreelancerJob

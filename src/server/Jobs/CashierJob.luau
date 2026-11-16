-- Kasjer: minigra w okienku. Serwer losuje zakupy klienta i zna poprawne odpowiedzi;
-- klient wysyła tylko wybrany produkt albo kwotę reszty. Odejście od kasy przerywa zmianę.
-- Klienci przychodzą do końca zmiany; cel na 3 gwiazdki to levelConfig.customers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local JobService = require(Services.JobService)

local CashierJob = {
	JobId = "cashier",
}

local CONFIG = JobsConfig.Jobs.cashier
local BANKNOTES = { 10, 20, 50, 100 }
local OPTION_COUNT = 6

local register = nil
local rng = Random.new()

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function randomProductId(): string
	return JobsConfig.Products[rng:NextInteger(1, #JobsConfig.Products)].id
end

local function scanOptions(target: string)
	local pool = {}
	for _, product in JobsConfig.Products do
		if product.id ~= target then
			table.insert(pool, product.id)
		end
	end
	shuffle(pool)
	local options = { target }
	for i = 1, OPTION_COUNT - 1 do
		table.insert(options, pool[i])
	end
	shuffle(options)
	return options
end

local function sendScan(session, mistake: boolean)
	local state = session.state
	local target = state.order[state.index]
	state.expected = target
	JobService.UpdateProgress(session, state.served, state.target, "Skanuj produkty klienta", {
		mode = "scan",
		customer = state.customer,
		goal = state.target,
		target = target,
		step = state.index,
		steps = #state.order,
		options = scanOptions(target),
		mistake = mistake,
	})
end

local function startChange(session)
	local state = session.state
	local total = 0
	for _, id in state.order do
		total += JobsConfig.GetProduct(id).price
	end
	local paid = BANKNOTES[#BANKNOTES]
	for _, note in BANKNOTES do
		if note > total then
			paid = note
			break
		end
	end
	local correct = paid - total
	local options = { correct }
	local candidates = {}
	for _, delta in { -5, -2, -1, 1, 2, 5, 10 } do
		local value = correct + delta
		if value > 0 then
			table.insert(candidates, value)
		end
	end
	shuffle(candidates)
	table.insert(options, candidates[1])
	table.insert(options, candidates[2])
	shuffle(options)

	state.stage = "change"
	state.correctChange = correct
	JobService.UpdateProgress(session, state.served, state.target, "Wydaj resztę", {
		mode = "change",
		customer = state.customer,
		goal = state.target,
		total = total,
		paid = paid,
		options = options,
	})
end

local function nextCustomer(session)
	local state = session.state
	state.customer += 1
	state.order = {}
	for i = 1, state.items do
		state.order[i] = randomProductId()
	end
	state.index = 1
	state.stage = "scan"
	sendScan(session, false)
end

function CashierJob.Init()
	register = Workspace.Map.JobSites:WaitForChild("Market"):WaitForChild("StartPart")
end

function CashierJob.StartShift(session)
	local state = session.state
	state.target = session.levelConfig.customers
	state.items = session.levelConfig.items
	state.customer = 0
	state.served = 0
	state.mistakes = 0
	state.lastAnswer = 0
	nextCustomer(session)
end

function CashierJob.OnAction(session, action: string, value: any)
	local state = session.state
	local now = os.clock()
	if now - state.lastAnswer < CONFIG.minAnswerInterval then
		return
	end
	state.lastAnswer = now

	if action == "scan" and state.stage == "scan" then
		if not RemoteService.IsString(value, 32) then
			return
		end
		if value == state.expected then
			state.index += 1
			if state.index > #state.order then
				startChange(session)
			else
				sendScan(session, false)
			end
		else
			state.mistakes += 1
			sendScan(session, true)
		end
	elseif action == "change" and state.stage == "change" then
		if not RemoteService.IsInteger(value, 0, 1000) then
			return
		end
		if value == state.correctChange then
			state.served += 1
		else
			state.mistakes += 1
		end
		nextCustomer(session)
	end
end

function CashierJob.TickShift(session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - register.Position).Magnitude > CONFIG.maxDistance then
		JobService.Cancel(session.player, "Za daleko od kasy. Zmiana przerwana.")
	end
end

-- 3 gwiazdki: cel osiągnięty i najwyżej maxMistakesFor3Stars pomyłek
function CashierJob.Evaluate(session): number
	local state = session.state
	local fraction = state.served / state.target
	if fraction >= 1 and state.mistakes <= CONFIG.maxMistakesFor3Stars then
		return 3
	end
	return math.min(2, JobService.StarsFromFraction(fraction))
end

return CashierJob

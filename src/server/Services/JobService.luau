-- Silnik prac: sesje z ID, zmiany na czas, gwiazdki, poziomy trudności i jednorazowa wypłata.
-- Każda praca to ModuleScript w ServerScriptService.Jobs z polem JobId.
-- Praca zmianowa implementuje: StartShift(session), Evaluate(session) -> gwiazdki 0-3,
-- opcjonalnie TickShift(session, dt), OnAction(session, akcja, wartość), Cleanup(session),
-- PayFactor(session) -> dodatkowy mnożnik wypłaty (np. cena złomu dnia).
-- UpdateProgress(done, total): total = cel na 3 gwiazdki, a każde zadanie ponad cel daje premię OVER_TARGET_BONUS.
-- Po osiągnięciu celu gracz może skończyć zmianę wcześniej (przycisk KONIEC) i dostać wypłatę od razu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local GoldenHourService = require(Services.GoldenHourService)

local JobService = {}

local TICK_INTERVAL = 0.25

local sessions = {} -- [player] = sesja
local jobs = {} -- [jobId] = moduł pracy
local startAttachments = {} -- [jobId] = Attachment przy miejscu pracy
local nextSessionId = 0
local jobObjects = nil
local lastShift = {} -- [player] = { jobId, startedAt, endedAt }
local shiftFinishedCallbacks = {}
local coopChecker = function(_player: Player, _session): boolean
	return false
end
local xpHandler = function(_player: Player, _jobId: string, _stars: number, _amount: number): number
	return 0
end

local function jobProgress(data, jobId: string)
	local progress = data.jobs[jobId]
	if type(progress) ~= "table" then
		progress = {}
		data.jobs[jobId] = progress
	end
	progress.completions = progress.completions or 0
	progress.goodCount = progress.goodCount or 0
	progress.threeStarCount = progress.threeStarCount or 0
	return progress
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Wspólne progi gwiazdek: 100% = 3, 70% = 2, 40% = 1
function JobService.StarsFromFraction(fraction: number): number
	if fraction >= 1 then
		return 3
	elseif fraction >= 0.7 then
		return 2
	elseif fraction >= 0.4 then
		return 1
	end
	return 0
end

function JobService.IsUnlocked(player: Player, jobId: string): boolean
	local definition = JobsConfig.Jobs[jobId]
	local data = DataService.Get(player)
	return definition ~= nil and data ~= nil and data.highestMonth >= definition.unlockMonth
end

function JobService.GetUnlockedLevel(player: Player, jobId: string): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local progress = jobProgress(data, jobId)
	local hard = JobsConfig.LevelRequirements[3]
	if progress.completions >= hard.completions and progress.threeStarCount >= hard.threeStars then
		return 3
	end
	if progress.goodCount >= JobsConfig.LevelRequirements[2].good then
		return 2
	end
	return 1
end

function JobService.GetSession(player: Player)
	return sessions[player]
end

-- Cel przewodnika: przy pierwszej zmianie w pracy (albo zawsze, gdy praca ma alwaysGuide) klient prowadzi
-- przerywaną linią do najbliższego oznaczonego obiektu w folderze sesji (GuideController).
-- label = napis nad celem; nil zdejmuje oznaczenie.
function JobService.SetGuideTarget(instance: Instance, label: string?)
	instance:SetAttribute("GuideTarget", if label then true else nil)
	instance:SetAttribute("GuideLabel", label)
end

function JobService.IsActive(session): boolean
	return sessions[session.player] == session
end

-- Zwraca sesję albo nil + powód ("busy", "locked")
function JobService.StartSession(player: Player, jobId: string)
	if sessions[player] then
		return nil, "busy"
	end
	if not JobService.IsUnlocked(player, jobId) then
		return nil, "locked"
	end
	nextSessionId += 1
	local session = {
		id = nextSessionId,
		jobId = jobId,
		player = player,
		startedAt = os.clock(),
		state = {},
	}
	sessions[player] = session
	return session
end

-- Premie i kary: wyspany (+10%), niewyspany (-10%), zimny prysznic (-10%)
function JobService.GetPayMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local multiplier = 1
	local stars = ApartmentConfig.StarsForScore(data.apartment.score)
	if stars >= 4 then
		multiplier += EconomyConfig.RESTED_BONUS
	elseif stars <= 1 then
		multiplier -= EconomyConfig.TIRED_PENALTY
	end
	if data.debt > 0 and data.warnings >= 2 then
		multiplier -= EconomyConfig.Landlord.COLD_SHOWER_PENALTY
	end
	-- Złota godzina na całym serwerze: x2
	multiplier += GoldenHourService.PayBonus()
	return multiplier
end

local function sendUpdate(session)
	local definition = JobsConfig.Jobs[session.jobId]
	local progress = session.progress
	RemoteService.Event(RemoteNames.Events.JobUpdate):FireClient(session.player, {
		active = true,
		jobId = session.jobId,
		name = definition.name,
		levelName = JobsConfig.LevelNames[session.level],
		endsIn = math.max(0, session.endsAt - os.clock()),
		done = progress.done,
		total = progress.total,
		hint = progress.hint,
		extra = progress.extra,
		combo = session.combo or 0,
		comboWindow = session.comboWindow,
		comboLeft = if session.lastDoneAt then math.max(0, session.comboWindow - (os.clock() - session.lastDoneAt)) else 0,
	})
end

-- Prace zmianowe wołają to po każdej zmianie postępu
function JobService.UpdateProgress(session, done: number, total: number, hint: string?, extra)
	-- Combo: kolejne zadanie w ciągu comboWindow sekund od poprzedniego przedłuża serię
	local before = if session.progress then tonumber(session.progress.done) or 0 else 0
	if type(done) == "number" and done > before then
		local now = os.clock()
		local window = session.comboWindow or JobsConfig.COMBO_WINDOW
		if session.lastDoneAt and now - session.lastDoneAt <= window then
			session.combo = (session.combo or 0) + 1
		else
			session.combo = 1
		end
		session.lastDoneAt = now
		session.comboWindow = window
		session.bestCombo = math.max(session.bestCombo or 0, session.combo)
	end
	session.progress = { done = done, total = total, hint = hint, extra = extra }
	if JobService.IsActive(session) then
		sendUpdate(session)
		if total > 0 and done >= total and not session.goalNotified then
			session.goalNotified = true
			StateService.Notify(session.player, "🎯 Cel! Kliknij KONIEC albo pracuj dalej po bonus!", "good")
		end
	end
end

local function goalReached(session): boolean
	local progress = session.progress
	local total = tonumber(progress and progress.total) or 0
	return total > 0 and (tonumber(progress.done) or 0) >= total
end

local function cleanupShift(session)
	local job = jobs[session.jobId]
	if job and job.Cleanup then
		local ok, err = pcall(job.Cleanup, session)
		if not ok then
			warn("[JobService] Błąd sprzątania po pracy " .. session.jobId .. ": " .. tostring(err))
		end
	end
	if session.folder then
		session.folder:Destroy()
	end
	RemoteService.Event(RemoteNames.Events.JobUpdate):FireClient(session.player, { active = false })
end

-- Przerywa sesję bez wypłaty
function JobService.Cancel(player: Player, reason: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.shift then
		cleanupShift(session)
	end
	if reason then
		StateService.Notify(player, reason, "warn")
	end
	StateService.Push(player)
end

-- Wypłata za pracę bez zmian (np. oddanie butelek). Sesja jest usuwana PRZED wypłatą,
-- więc tej samej sesji nie da się wypłacić dwa razy. Zwraca wypłaconą kwotę.
function JobService.Complete(player: Player, session, baseAmount: number, reason: string): number
	if sessions[player] ~= session then
		return 0
	end
	sessions[player] = nil
	local data = DataService.Get(player)
	if not data or type(baseAmount) ~= "number" or baseAmount <= 0 then
		StateService.Push(player)
		return 0
	end
	local amount = math.floor(baseAmount * JobService.GetPayMultiplier(player) + 0.5)
	if amount < 1 then
		StateService.Push(player)
		return 0
	end
	jobProgress(data, session.jobId).completions += 1
	EconomyService.AddCoins(player, amount, "job:" .. session.jobId .. ":" .. reason)
	return amount
end

-- Koniec zmiany: gwiazdki z Evaluate, wypłata = basePay x poziom x gwiazdki x premie
local function finishShift(session, timedOut: boolean): number
	local player = session.player
	if sessions[player] ~= session then
		return 0
	end
	sessions[player] = nil
	lastShift[player] = { jobId = session.jobId, startedAt = session.startedAt, endedAt = os.clock() }

	local job = jobs[session.jobId]
	local ok, result = pcall(job.Evaluate, session)
	local stars = if ok and type(result) == "number" then math.clamp(math.floor(result), 0, 3) else 0
	cleanupShift(session)

	local definition = JobsConfig.Jobs[session.jobId]
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local elapsed = os.clock() - session.startedAt
	-- Cel osiągnięty (każde zadanie sprawdza serwer) = KONIEC zawsze płaci, nawet przy szybkim graczu.
	-- Minimalny czas chroni tylko zmiany zakończone bez osiągnięcia celu.
	if elapsed < definition.minShiftTime and not goalReached(session) then
		warn(string.format("[JobService] %s: %s ukończone w %.1f s (minimum %d s). Brak wypłaty.", player.Name, session.jobId, elapsed, definition.minShiftTime))
		RemoteService.Event(RemoteNames.Events.JobResult):FireClient(player, {
			name = definition.name,
			stars = 0,
			amount = 0,
			tooFast = true,
		})
		StateService.Push(player)
		return 0
	end

	local progress = jobProgress(data, session.jobId)
	local levelBefore = JobService.GetUnlockedLevel(player, session.jobId)
	progress.completions += 1
	if stars >= 2 then
		progress.goodCount += 1
	end
	if stars == 3 then
		progress.threeStarCount += 1
	end

	local multiplier = JobService.GetPayMultiplier(player)
	local target = tonumber(session.progress.total) or 0
	local overTarget = (tonumber(session.progress.done) or 0) - target
	if target > 0 and overTarget > 0 then
		multiplier += math.min(JobsConfig.OVER_TARGET_MAX, overTarget * JobsConfig.OVER_TARGET_BONUS)
	end
	local coop = false
	if target <= 0 or (tonumber(session.progress.done) or 0) >= target * JobsConfig.COOP_MIN_SHARE then
		local coopOk, isCoop = pcall(coopChecker, player, session)
		coop = coopOk and isCoop == true
	end
	if coop then
		multiplier += JobsConfig.COOP_BONUS
	end
	if data.stats.nextShiftBonus then
		multiplier += JobsConfig.STREAK_BONUS
		data.stats.nextShiftBonus = false
	end
	-- Najdłuższa seria w zmianie: pełna seria przez cały cel = COMBO_MAX_BONUS
	local bestCombo = session.bestCombo or 0
	local comboBonus = 0
	if target > 0 and bestCombo >= 2 then
		comboBonus = JobsConfig.COMBO_MAX_BONUS * math.clamp((bestCombo - 1) / math.max(1, target - 1), 0, 1)
		comboBonus = math.floor(comboBonus * 100 + 0.5) / 100
		multiplier += comboBonus
	end
	if stars == 3 then
		data.stats.threeStarStreak += 1
		if data.stats.threeStarStreak >= 3 then
			data.stats.threeStarStreak = 0
			data.stats.nextShiftBonus = true
			StateService.Notify(player, "Seria fachowca! +10% do następnej zmiany", "good")
		end
	else
		data.stats.threeStarStreak = 0
	end

	local base = definition.basePay * EconomyConfig.DifficultyMultiplier[session.level] * EconomyConfig.StarMultiplier[stars]
	if job.PayFactor then
		local factorOk, factor = pcall(job.PayFactor, session)
		if factorOk and type(factor) == "number" then
			base *= math.clamp(factor, 0.5, 2)
		end
	end
	local amount = math.floor(base * multiplier + 0.5)
	if amount >= 1 then
		EconomyService.AddCoins(player, amount, "job:" .. session.jobId .. ":" .. stars .. "star")
	end
	-- Rekordy tej pracy (najwyższa wypłata i najdłuższa seria)
	local previousBest = progress.best or 0
	local record = previousBest > 0 and amount > previousBest
	if amount > previousBest then
		progress.best = amount
	end
	if bestCombo > (progress.bestCombo or 0) then
		progress.bestCombo = bestCombo
	end
	local xpOk, xp = pcall(xpHandler, player, session.jobId, stars, amount)
	if not xpOk then
		warn("[JobService] Błąd XP: " .. tostring(xp))
	end
	local levelAfter = JobService.GetUnlockedLevel(player, session.jobId)
	for _, callback in shiftFinishedCallbacks do
		task.spawn(callback, player, session.jobId, stars, amount)
	end
	RemoteService.Event(RemoteNames.Events.JobResult):FireClient(player, {
		name = definition.name,
		stars = stars,
		amount = amount,
		timedOut = timedOut,
		coop = coop,
		levelUnlocked = if levelAfter > levelBefore then JobsConfig.LevelNames[levelAfter] else nil,
		combo = bestCombo,
		comboBonus = math.floor(comboBonus * 100 + 0.5),
		record = record,
		best = previousBest,
		golden = GoldenHourService.IsActive(),
		xp = if xpOk and type(xp) == "number" then xp else 0,
	})
	StateService.Push(player)
	return amount
end

-- callback(player, jobId, gwiazdki, kwota) po każdej zakończonej zmianie (zadania dnia i tygodnia)
function JobService.OnShiftFinished(callback)
	table.insert(shiftFinishedCallbacks, callback)
end

function JobService.GetLastShift(player: Player)
	return lastShift[player]
end

-- checker(player, session) -> true, gdy gracz pracował razem z kimś z ekipy (RoommateService)
function JobService.SetCoopChecker(checker)
	coopChecker = checker
end

-- handler(player, jobId, gwiazdki, kwota) -> zdobyte XP (XpService); liczba trafia do okna wyniku
function JobService.SetXpHandler(handler)
	xpHandler = handler
end

-- Praca woła to, gdy gracz wykonał wszystkie zadania przed czasem
function JobService.CompleteShift(session): number
	return finishShift(session, false)
end

local function nearStart(player: Player, jobId: string): boolean
	local attachment = startAttachments[jobId]
	local root = getRoot(player)
	return attachment ~= nil and root ~= nil and (root.Position - attachment.WorldPosition).Magnitude <= JobsConfig.START_DISTANCE
end

local function buildMenu(player: Player, jobId: string)
	local definition = JobsConfig.Jobs[jobId]
	local data = DataService.Get(player)
	local progress = jobProgress(data, jobId)
	local unlocked = JobService.GetUnlockedLevel(player, jobId)
	local medium = JobsConfig.LevelRequirements[2]
	local hard = JobsConfig.LevelRequirements[3]
	local levels = {}
	for level = 1, 3 do
		local requirement = nil
		if level == 2 then
			requirement = string.format("%d/%d zmian na 2★", math.min(progress.goodCount, medium.good), medium.good)
		elseif level == 3 then
			requirement = string.format(
				"%d/%d zmian, %d/%d na 3★",
				math.min(progress.completions, hard.completions),
				hard.completions,
				math.min(progress.threeStarCount, hard.threeStars),
				hard.threeStars
			)
		end
		table.insert(levels, {
			name = JobsConfig.LevelNames[level],
			unlocked = level <= unlocked,
			pay = math.floor(definition.basePay * EconomyConfig.DifficultyMultiplier[level] + 0.5),
			requirement = requirement,
		})
	end
	return {
		jobId = jobId,
		name = definition.name,
		description = definition.description,
		shift = definition.shift,
		levels = levels,
	}
end

local function onStartPrompt(player: Player, jobId: string)
	if not nearStart(player, jobId) or not DataService.Get(player) then
		return
	end
	local current = sessions[player]
	if current then
		local message = if current.jobId == "cans" then "Najpierw wrzuć butelki do kaucjomatu." else "Już pracujesz!"
		StateService.Notify(player, message, "warn")
		return
	end
	local definition = JobsConfig.Jobs[jobId]
	if not JobService.IsUnlocked(player, jobId) then
		StateService.Notify(player, string.format("%s: odblokujesz w miesiącu %d.", definition.name, definition.unlockMonth), "info")
		return
	end
	RemoteService.Event(RemoteNames.Events.OpenJobMenu):FireClient(player, buildMenu(player, jobId))
end

local function onStartJob(player: Player, jobId: any, level: any)
	if not RemoteService.IsString(jobId, 32) or not JobsConfig.Jobs[jobId] or not RemoteService.IsInteger(level, 1, 3) then
		return
	end
	local job = jobs[jobId]
	if not job or not job.StartShift then
		return
	end
	if not nearStart(player, jobId) then
		StateService.Notify(player, "Podejdź bliżej miejsca pracy.", "warn")
		return
	end
	if level > JobService.GetUnlockedLevel(player, jobId) then
		return
	end
	local session, reason = JobService.StartSession(player, jobId)
	if not session then
		if reason == "busy" then
			StateService.Notify(player, "Najpierw skończ obecną pracę.", "warn")
		end
		return
	end

	local definition = JobsConfig.Jobs[jobId]
	session.shift = true
	session.level = level
	session.levelConfig = definition.levels[level]
	session.endsAt = os.clock() + definition.shift
	session.progress = { done = 0, total = 0 }
	session.combo = 0
	session.comboWindow = definition.comboWindow or JobsConfig.COMBO_WINDOW
	local folder = Instance.new("Folder")
	folder.Name = "Session_" .. session.id
	folder:SetAttribute("JobOwner", player.UserId)
	local data = DataService.Get(player)
	if definition.alwaysGuide or (data and jobProgress(data, jobId).completions == 0) then
		folder:SetAttribute("Guide", true)
	end
	folder.Parent = jobObjects
	session.folder = folder

	local ok, err = pcall(job.StartShift, session)
	if not ok then
		warn("[JobService] Nie udało się rozpocząć " .. jobId .. ": " .. tostring(err))
		JobService.Cancel(player, "Nie udało się rozpocząć pracy.")
		return
	end
	StateService.Notify(player, definition.name .. ": zmiana się zaczęła!", "info")
	sendUpdate(session)
	StateService.Push(player)
end

local function onJobAction(player: Player, action: any, value: any)
	local session = sessions[player]
	if not session or not session.shift or not RemoteService.IsString(action, 32) then
		return
	end
	local job = jobs[session.jobId]
	if job.OnAction then
		job.OnAction(session, action, value)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterRemoving:Connect(function()
		local session = sessions[player]
		if session and session.shift then
			JobService.Cancel(player, "Zmiana przerwana.")
		end
	end)
end

function JobService.Init()
	jobObjects = Instance.new("Folder")
	jobObjects.Name = "JobObjects"
	jobObjects.Parent = Workspace

	local sites = Workspace:WaitForChild("Map"):WaitForChild("JobSites")
	for jobId, definition in JobsConfig.Jobs do
		if definition.site then
			local site = sites:FindFirstChild(definition.site)
			local startPart = site and site:FindFirstChild("StartPart")
			local attachment = startPart and startPart:FindFirstChild("StartAttachment")
			if attachment then
				startAttachments[jobId] = attachment
			else
				warn("[JobService] Brak miejsca pracy dla " .. jobId)
			end
		end
	end

	for _, child in ServerScriptService.Jobs:GetChildren() do
		if child:IsA("ModuleScript") then
			local job = require(child)
			if type(job) == "table" and type(job.JobId) == "string" and JobsConfig.Jobs[job.JobId] then
				jobs[job.JobId] = job
			else
				warn("[JobService] Pominięto moduł bez poprawnego JobId: " .. child.Name)
			end
		end
	end
	for _, job in jobs do
		if job.Init then
			job.Init()
		end
	end

	RemoteService.OnServerEvent(RemoteNames.Events.StartJob, 2, onStartJob)
	RemoteService.OnServerEvent(RemoteNames.Events.CancelJob, 2, function(player)
		local session = sessions[player]
		if not session or not session.shift then
			return
		end
		-- Cel osiągnięty: KONIEC = normalna wypłata za to, co zrobiono (z premią za nadwyżkę)
		if goalReached(session) then
			finishShift(session, false)
		else
			JobService.Cancel(player, "Zmiana przerwana. Bez wypłaty.")
		end
	end)
	RemoteService.OnServerEvent(RemoteNames.Events.JobAction, 10, onJobAction)

	StateService.AddProvider(function(player, snapshot)
		local bonus = math.floor((JobService.GetPayMultiplier(player) - 1) * 100 + 0.5)
		if bonus ~= 0 then
			snapshot.payBonus = bonus
		end
	end)
end

function JobService.Start()
	for jobId, attachment in startAttachments do
		local prompt = attachment:FindFirstChild("StartPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onStartPrompt(player, jobId)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		JobService.Cancel(player)
		lastShift[player] = nil
	end)
	for _, job in jobs do
		if job.Start then
			job.Start()
		end
	end

	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			local now = os.clock()
			for player, session in sessions do
				if session.shift then
					local job = jobs[session.jobId]
					if job.TickShift then
						local ok, err = pcall(job.TickShift, session, TICK_INTERVAL)
						if not ok then
							warn("[JobService] Błąd w " .. session.jobId .. ": " .. tostring(err))
						end
					end
					if sessions[player] == session and now >= session.endsAt then
						finishShift(session, true)
					end
				end
			end
		end
	end)
end

return JobService

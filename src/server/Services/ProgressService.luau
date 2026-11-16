-- Powroty codzienne: Kalendarz Lokatora (7 nagród, bez kary za przerwę), 3 zadania dnia, 3 wyzwania tygodnia
-- i wspólne wyzwanie serwera. Postęp zbierają inne serwisy przez ProgressService.Record(gracz, rodzaj, ile).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProgressConfig = require(ReplicatedStorage.Shared.Config.ProgressConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Format = require(ReplicatedStorage.Shared.Modules.Format)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local CleaningService = require(Services.CleaningService)
local JobService = require(Services.JobService)
local AchievementService = require(Services.AchievementService)

local ProgressService = {}

-- Powody zarobku, które liczą się do zadań "zarób" (bez nagród za same zadania, żeby nie było pętli)
local EARN_PREFIXES = { "job:", "rare:", "help:" }

local serverChallenge = nil

local function dueOf(data): number
	return EconomyConfig.GetDue(data.month)
end

local function rewardValues(data, reward)
	return math.max(10, math.floor(dueOf(data) * reward.coinsFactor + 0.5)), reward.tokens
end

local function rewardText(data, reward): string
	local coins, tokens = rewardValues(data, reward)
	return string.format("+%s monet, +%d %s", Format.Number(coins), tokens, Format.Plural(tokens, "klucz", "klucze", "kluczy"))
end

local function buildTasks(pool, count: number, rng, data)
	local order = {}
	for index in pool do
		table.insert(order, index)
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local list = {}
	for i = 1, math.min(count, #order) do
		local definition = pool[order[i]]
		local target = definition.target or math.max(50, math.floor(dueOf(data) * definition.targetFactor + 0.5))
		table.insert(list, {
			kind = definition.kind,
			text = string.format(definition.text, target),
			target = target,
			progress = 0,
			done = false,
		})
	end
	return list
end

-- Nowy dzień = nowe zadania; nowy tydzień = nowe wyzwania i wyzerowane statystyki do rankingu
local function ensurePeriods(player: Player, data)
	local today = ProgressConfig.Today()
	if data.daily.questDay ~= today then
		local rng = Random.new(today * 7919 + math.abs(player.UserId) % 100000)
		data.daily.quests = buildTasks(ProgressConfig.DailyQuests, ProgressConfig.DAILY_QUEST_COUNT, rng, data)
		data.daily.questDay = today
	end
	local week = ProgressConfig.WeekOf(today)
	if data.weekly.week ~= week then
		local rng = Random.new(week * 104729 + math.abs(player.UserId) % 100000)
		data.weekly.challenges = buildTasks(ProgressConfig.WeeklyChallenges, ProgressConfig.WEEKLY_CHALLENGE_COUNT, rng, data)
		data.weekly.stats = { earned = 0, cleaned = 0, monthsPaid = 0 }
		data.weekly.week = week
	end
end

function ProgressService.EnsurePeriods(player: Player)
	local data = DataService.Get(player)
	if data then
		ensurePeriods(player, data)
	end
end

local function pushProgress(player: Player)
	RemoteService.Event(RemoteNames.Events.ProgressUpdate):FireClient(player)
end

local function grant(player: Player, data, reward, reason: string)
	local coins, tokens = rewardValues(data, reward)
	data.tokens += tokens
	EconomyService.AddCoins(player, coins, reason)
end

local function newServerChallenge(round: number)
	local pool = ProgressConfig.ServerChallenges
	local definition = pool[(round - 1) % #pool + 1]
	local players = math.max(1, #Players:GetPlayers())
	local growth = ProgressConfig.SERVER_ROUND_GROWTH ^ math.floor((round - 1) / #pool)
	local target = math.floor((definition.base + definition.perPlayer * (players - 1)) * growth + 0.5)
	serverChallenge = {
		round = round,
		kind = definition.kind,
		text = string.format(definition.text, target),
		target = target,
		progress = 0,
		contributors = {},
	}
end

local function advanceServerChallenge(player: Player, kind: string, amount: number)
	if not serverChallenge or serverChallenge.kind ~= kind then
		return
	end
	serverChallenge.progress += amount
	serverChallenge.contributors[player] = true
	if serverChallenge.progress < serverChallenge.target then
		return
	end
	local reward = ProgressConfig.SERVER_REWARD_TOKENS
	for contributor in serverChallenge.contributors do
		local data = contributor.Parent and DataService.Get(contributor)
		if data then
			data.tokens += reward
			StateService.Notify(contributor, string.format("🎉 Wyzwanie serwera wykonane! +%d kluczy dla wszystkich pomocników", reward), "good")
			StateService.Push(contributor)
		end
	end
	newServerChallenge(serverChallenge.round + 1)
	for _, other in Players:GetPlayers() do
		pushProgress(other)
	end
end

-- Główne wejście: kind = "clean", "shifts", "stars3", "earn", "cans", "monthsPaid", "rare"
function ProgressService.Record(player: Player, kind: string, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	ensurePeriods(player, data)
	local stats = data.weekly.stats
	if kind == "earn" then
		stats.earned += amount
	elseif kind == "clean" then
		stats.cleaned += amount
	elseif kind == "monthsPaid" then
		stats.monthsPaid += amount
	end

	local changed = false
	for _, quest in data.daily.quests do
		if not quest.done and quest.kind == kind then
			quest.progress = math.min(quest.target, quest.progress + amount)
			changed = true
			if quest.progress >= quest.target then
				quest.done = true
				grant(player, data, ProgressConfig.DAILY_REWARD, "quest:daily")
				StateService.Notify(player, "✅ Zadanie dnia: " .. quest.text .. "! " .. rewardText(data, ProgressConfig.DAILY_REWARD), "good")
			end
		end
	end
	for _, challenge in data.weekly.challenges do
		if not challenge.done and challenge.kind == kind then
			challenge.progress = math.min(challenge.target, challenge.progress + amount)
			changed = true
			if challenge.progress >= challenge.target then
				challenge.done = true
				grant(player, data, ProgressConfig.WEEKLY_REWARD, "quest:weekly")
				StateService.Notify(player, "🏆 Wyzwanie tygodnia: " .. challenge.text .. "! " .. rewardText(data, ProgressConfig.WEEKLY_REWARD), "good")
			end
		end
	end
	advanceServerChallenge(player, kind, amount)
	if changed then
		pushProgress(player)
	end
end

local function calendarReward(data, index: number)
	local reward = ProgressConfig.Calendar[index]
	if reward.kind == "coins" then
		local coins = math.max(10, math.floor(dueOf(data) * reward.factor + 0.5))
		return reward, coins, string.format("%s monet", Format.Number(coins))
	elseif reward.kind == "tokens" then
		return reward, reward.amount, string.format("%d %s", reward.amount, Format.Plural(reward.amount, "klucz", "klucze", "kluczy"))
	end
	local item = ShopConfig.Items[reward.item]
	if AchievementService.OwnsFurniture(data, reward.item) then
		return reward, reward.fallbackTokens, string.format("%d kluczy", reward.fallbackTokens)
	end
	return reward, 0, item.emoji .. " " .. item.name
end

local function claimDaily(player: Player)
	local data = DataService.Get(player)
	if not data then
		return { ok = false, message = "Chwila, wczytuję dane..." }
	end
	local today = ProgressConfig.Today()
	if data.daily.lastDay >= today then
		return { ok = false, message = "Nagroda na dziś już odebrana. Wróć jutro!" }
	end
	local index = data.daily.calendarIndex % #ProgressConfig.Calendar + 1
	local reward, value, label = calendarReward(data, index)
	if reward.kind == "coins" then
		EconomyService.AddCoins(player, value, "calendar")
	elseif reward.kind == "tokens" or value > 0 then
		data.tokens += value
	else
		AchievementService.GrantFurniture(player, data, reward.item)
	end
	data.daily.lastDay = today
	data.daily.calendarIndex = index % #ProgressConfig.Calendar
	StateService.Notify(player, string.format("🎁 Nagroda dnia %d: %s!", index, label), "good")
	StateService.Push(player)
	return { ok = true, message = "Odebrano: " .. label }
end

function ProgressService.Build(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	ensurePeriods(player, data)
	local today = ProgressConfig.Today()
	local rewards = {}
	for index in ProgressConfig.Calendar do
		local _, _, label = calendarReward(data, index)
		table.insert(rewards, label)
	end
	return {
		calendar = {
			next = data.daily.calendarIndex % #ProgressConfig.Calendar + 1,
			canClaim = data.daily.lastDay < today,
			rewards = rewards,
		},
		daily = data.daily.quests,
		dailyReward = rewardText(data, ProgressConfig.DAILY_REWARD),
		weekly = data.weekly.challenges,
		weeklyReward = rewardText(data, ProgressConfig.WEEKLY_REWARD),
		daysLeftInWeek = 7 - (today + 3) % 7,
		server = serverChallenge and {
			text = serverChallenge.text,
			progress = math.min(serverChallenge.progress, serverChallenge.target),
			target = serverChallenge.target,
			reward = ProgressConfig.SERVER_REWARD_TOKENS,
		},
		achievements = AchievementService.BuildList(player),
	}
end

-- Tylko do testów w Studio: "nowy dzień" (można znowu odebrać nagrodę, nowe zadania)
function ProgressService.DebugNewDay(player: Player)
	local data = DataService.Get(player)
	if data then
		data.daily.lastDay = 0
		data.daily.questDay = 0
		ensurePeriods(player, data)
		StateService.Push(player)
		pushProgress(player)
	end
end

local function startsWithAny(text: string, prefixes): boolean
	for _, prefix in prefixes do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function ProgressService.Init()
	newServerChallenge(1)
	RemoteService.OnServerInvoke(RemoteNames.Functions.GetProgress, 3, ProgressService.Build)
	RemoteService.OnServerInvoke(RemoteNames.Functions.ClaimDaily, 2, claimDaily)

	CleaningService.OnCleaned(function(_owner, cleaner)
		ProgressService.Record(cleaner, "clean", 1)
	end)
	JobService.OnShiftFinished(function(player, _jobId, stars)
		ProgressService.Record(player, "shifts", 1)
		if stars == 3 then
			ProgressService.Record(player, "stars3", 1)
		end
	end)
	EconomyService.OnEarned(function(player, amount, reason)
		if startsWithAny(reason, EARN_PREFIXES) then
			ProgressService.Record(player, "earn", amount)
		end
	end)

	StateService.AddProvider(function(_player, snapshot, data)
		snapshot.progressBadge = data.daily.lastDay < ProgressConfig.Today()
	end)
	DataService.OnLoaded(function(player, data)
		ensurePeriods(player, data)
		if data.daily.lastDay < ProgressConfig.Today() then
			task.delay(4, function()
				if player.Parent then
					StateService.Notify(player, "🎁 Nagroda dnia czeka! Kliknij 📋 ZADANIA.", "info")
				end
			end)
		end
	end)
end

return ProgressService

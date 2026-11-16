-- Ekipa (1-4 graczy): współlokatorzy, "drzwi otwarte", obowiązki domowe i premia za wspólną pracę.
-- Każdy zachowuje własny postęp i własny czynsz; współlokatorzy płacą mniej (EconomyConfig.ROOMMATE_DISCOUNT)
-- i mieszkają w mieszkaniu gospodarza. Ekipa istnieje tylko w trakcie gry (nie jest zapisywana).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ApartmentConfig = require(ReplicatedStorage.Shared.Config.ApartmentConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local ApartmentService = require(Services.ApartmentService)
local JobService = require(Services.JobService)
local CleaningService = require(Services.CleaningService)

local RoommateService = {}

local MAX_MEMBERS = 4
local INVITE_TIME = 30
local CHORE_KINDS = { "trash", "stain", "dishes", "bug", "mold" }

local households = {} -- [gospodarz] = { host, members, doorOpen, contributions = { [userId] = liczba } }
local memberOf = {} -- [gracz] = ekipa (również gospodarz)
local invites = {} -- [zaproszony] = { host, expires }

function RoommateService.IsGuest(player: Player): boolean
	local household = memberOf[player]
	return household ~= nil and household.host ~= player
end

function RoommateService.GetHomeOwner(player: Player): Player
	local household = memberOf[player]
	return if household then household.host else player
end

function RoommateService.GetHouseholdSize(player: Player): number
	local household = memberOf[player]
	return if household then #household.members else 1
end

local function ensureHousehold(host: Player)
	local household = households[host]
	if not household then
		household = { host = host, members = { host }, doorOpen = false, contributions = {} }
		households[host] = household
		memberOf[host] = household
	end
	return household
end

-- Ekipa jednoosobowa bez otwartych drzwi nie jest potrzebna
local function tidy(household)
	if #household.members <= 1 and not household.doorOpen then
		households[household.host] = nil
		memberOf[household.host] = nil
	end
end

local function canAccess(owner: Player, player: Player): boolean
	if owner == player then
		return true
	end
	local household = households[owner]
	return household ~= nil and (household.doorOpen or table.find(household.members, player) ~= nil)
end

local function discountPercent(size: number): number
	return math.floor((EconomyConfig.ROOMMATE_DISCOUNT[math.clamp(size, 1, MAX_MEMBERS)] or 0) * 100 + 0.5)
end

local function notify(player: Player, text: string, kind: string)
	if player.Parent then
		StateService.Notify(player, text, kind)
	end
end

-- Widok panelu "Ekipa" dla gracza
local function buildState(player: Player)
	local own = memberOf[player]
	local host = if own then own.host else player
	local household = households[host]
	local size = if household then #household.members else 1

	local members = {}
	local contributions = {}
	for _, member in (if household then household.members else { player }) do
		table.insert(members, { name = member.DisplayName, isHost = member == host })
		table.insert(contributions, { name = member.DisplayName, count = if household then household.contributions[member.UserId] or 0 else 0 })
	end

	local chores = { failures = {} }
	for _, kind in CHORE_KINDS do
		chores[kind] = ApartmentService.CountDirt(host, kind)
	end
	local hostData = DataService.Get(host)
	if hostData then
		for failureId in hostData.apartment.failures do
			local definition = ApartmentConfig.Failures[failureId]
			if definition then
				table.insert(chores.failures, definition.name)
			end
		end
	end

	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local theirs = memberOf[other]
			local status = "free"
			if theirs and theirs == own and #theirs.members > 1 then
				status = "together"
			elseif theirs and #theirs.members > 1 then
				status = "busy"
			end
			table.insert(others, { userId = other.UserId, name = other.DisplayName, status = status })
		end
	end

	return {
		hostName = host.DisplayName,
		isHost = host == player,
		members = members,
		doorOpen = household ~= nil and household.doorOpen,
		size = size,
		discount = discountPercent(size),
		canInvite = host == player and size < MAX_MEMBERS,
		players = others,
		chores = chores,
		contributions = contributions,
	}
end

local function pushPlayer(player: Player)
	if player.Parent and DataService.Get(player) then
		RemoteService.Event(RemoteNames.Events.SocialState):FireClient(player, buildState(player))
	end
end

-- Zmiana składu ekip: odśwież panel i czynsz u wszystkich
local function pushAll()
	for _, player in Players:GetPlayers() do
		pushPlayer(player)
		StateService.Push(player)
	end
end

local function removeMember(household, player: Player)
	local index = table.find(household.members, player)
	if index then
		table.remove(household.members, index)
	end
	memberOf[player] = nil
	if player.Parent then
		ApartmentService.TeleportToApartment(player, player)
	end
end

local function dissolve(household, message: string)
	for _, member in table.clone(household.members) do
		if member ~= household.host then
			removeMember(household, member)
			notify(member, message, "warn")
		end
	end
	households[household.host] = nil
	memberOf[household.host] = nil
end

local function invite(player: Player, userId: any)
	-- W teście lokalnym Studio gracze mają ujemne UserId (-1, -2...), więc dopuszczamy oba znaki
	if not RemoteService.IsInteger(userId, -1e15, 1e15) or userId == 0 then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player then
		notify(player, "Tego gracza nie ma już na serwerze.", "warn")
		return
	end
	if not DataService.Get(target) then
		notify(player, target.DisplayName .. " jeszcze się wczytuje. Spróbuj za chwilę.", "info")
		return
	end
	if RoommateService.IsGuest(player) then
		notify(player, "Zapraszać może tylko gospodarz mieszkania.", "warn")
		return
	end
	local household = households[player]
	local size = if household then #household.members else 1
	if size >= MAX_MEMBERS then
		notify(player, "Mieszkanie jest pełne (4 osoby).", "warn")
		return
	end
	local theirs = memberOf[target]
	if theirs and #theirs.members > 1 then
		notify(player, target.DisplayName .. " ma już swoją ekipę.", "info")
		return
	end
	invites[target] = { host = player, expires = os.clock() + INVITE_TIME }
	RemoteService.Event(RemoteNames.Events.SocialInvite):FireClient(target, {
		hostName = player.DisplayName,
		discount = discountPercent(size + 1),
		expiresIn = INVITE_TIME,
	})
	notify(player, "Wysłano zaproszenie: " .. target.DisplayName, "info")
end

local function accept(player: Player)
	local pending = invites[player]
	invites[player] = nil
	if not pending or os.clock() > pending.expires or not pending.host.Parent then
		notify(player, "Zaproszenie wygasło.", "warn")
		return
	end
	local host = pending.host
	if RoommateService.IsGuest(host) then
		notify(player, "Ten gracz mieszka teraz u kogoś innego.", "warn")
		return
	end
	local current = memberOf[player]
	if current and #current.members > 1 then
		notify(player, "Najpierw opuść swoją ekipę.", "warn")
		return
	end
	local household = ensureHousehold(host)
	if #household.members >= MAX_MEMBERS then
		notify(player, "To mieszkanie jest już pełne.", "warn")
		return
	end
	if current then
		-- jednoosobowa ekipa z otwartymi drzwiami przestaje być potrzebna
		households[player] = nil
		memberOf[player] = nil
	end
	table.insert(household.members, player)
	memberOf[player] = household
	ApartmentService.TeleportToApartment(player, host)
	notify(player, string.format("Mieszkasz teraz u: %s. Czynsz -%d%%!", host.DisplayName, discountPercent(#household.members)), "good")
	notify(host, player.DisplayName .. " dołącza do Twojego mieszkania!", "good")
	pushAll()
end

local function leave(player: Player)
	local household = memberOf[player]
	if not household then
		return
	end
	if household.host == player then
		dissolve(household, "Wspólne mieszkanie zostało rozwiązane. Wracasz do siebie.")
		notify(player, "Wspólne mieszkanie rozwiązane.", "info")
	else
		removeMember(household, player)
		notify(player, "Wyprowadzka zakończona. Wracasz do swojego mieszkania.", "info")
		notify(household.host, player.DisplayName .. " wyprowadza się.", "info")
		tidy(household)
	end
	pushAll()
end

local function toggleDoor(player: Player)
	if RoommateService.IsGuest(player) then
		return
	end
	local household = ensureHousehold(player)
	household.doorOpen = not household.doorOpen
	if household.doorOpen then
		notify(player, "Drzwi otwarte: każdy może wejść i pomóc w sprzątaniu.", "info")
	else
		notify(player, "Drzwi zamknięte: wchodzą tylko współlokatorzy.", "info")
	end
	tidy(household)
	pushAll()
end

local function onAction(player: Player, action: any, value: any)
	if action == "invite" then
		invite(player, value)
	elseif action == "accept" then
		accept(player)
	elseif action == "decline" then
		local pending = invites[player]
		invites[player] = nil
		if pending then
			notify(pending.host, player.DisplayName .. " nie przyjmuje zaproszenia.", "info")
		end
	elseif action == "leave" then
		leave(player)
	elseif action == "toggleDoor" then
		toggleDoor(player)
	end
end

-- Premia za wspólną pracę: ktoś z ekipy pracuje (albo pracował) w tej samej pracy w tym samym czasie
local function isCoopShift(player: Player, session): boolean
	local household = memberOf[player]
	if not household then
		return false
	end
	for _, member in household.members do
		if member ~= player then
			local theirs = JobService.GetSession(member)
			if theirs and theirs.jobId == session.jobId then
				return true
			end
			local last = JobService.GetLastShift(member)
			if last and last.jobId == session.jobId and last.endedAt >= session.startedAt then
				return true
			end
		end
	end
	return false
end

local function onPlayerRemoving(player: Player)
	invites[player] = nil
	for invitee, pending in invites do
		if pending.host == player then
			invites[invitee] = nil
		end
	end
	local household = memberOf[player]
	if household then
		if household.host == player then
			dissolve(household, player.DisplayName .. " wychodzi z gry. Wracasz do swojego mieszkania.")
		else
			removeMember(household, player)
			notify(household.host, player.DisplayName .. " wychodzi z gry i opuszcza mieszkanie.", "info")
			tidy(household)
		end
	end
	task.defer(pushAll)
end

function RoommateService.Init()
	ApartmentService.SetAccessChecker(canAccess)
	ApartmentService.SetDirtPausedChecker(RoommateService.IsGuest)
	ApartmentService.SetHomeResolver(RoommateService.GetHomeOwner)
	StateService.SetHouseholdSizeGetter(RoommateService.GetHouseholdSize)
	JobService.SetCoopChecker(isCoopShift)

	RemoteService.OnServerInvoke(RemoteNames.Functions.GetSocial, 3, buildState)
	RemoteService.OnServerEvent(RemoteNames.Events.SocialAction, 4, onAction)
	RemoteService.OnServerEvent(RemoteNames.Events.GoHome, 1, function(player)
		ApartmentService.TeleportToApartment(player, RoommateService.GetHomeOwner(player))
	end)

	-- Przeprowadzka gospodarza: współlokatorzy jadą razem z nim
	ApartmentService.OnMoved(function(host: Player)
		local household = households[host]
		if household then
			for _, member in household.members do
				if member ~= host then
					ApartmentService.TeleportToApartment(member, host)
				end
			end
			pushAll()
		end
	end)

	-- Obowiązki: kto ile posprzątał we wspólnym mieszkaniu
	CleaningService.OnCleaned(function(owner: Player, cleaner: Player)
		local household = households[owner]
		if household and table.find(household.members, cleaner) then
			household.contributions[cleaner.UserId] = (household.contributions[cleaner.UserId] or 0) + 1
			for _, member in household.members do
				pushPlayer(member)
			end
		end
	end)
end

function RoommateService.Start()
	Players.PlayerAdded:Connect(function()
		task.delay(3, pushAll)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return RoommateService

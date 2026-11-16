-- Komendy testowe. Działają WYŁĄCZNIE w Roblox Studio, na żywym serwerze są ignorowane.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Modules.RemoteNames)
local Services = ServerScriptService.Services
local RemoteService = require(Services.RemoteService)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local ApartmentService = require(Services.ApartmentService)
local MonthService = require(Services.MonthService)
local RareContractService = require(Services.RareContractService)
local FailureService = require(Services.FailureService)
local EventService = require(Services.EventService)
local ProgressService = require(Services.ProgressService)
local LeaderboardService = require(Services.LeaderboardService)
local CosmeticsService = require(Services.CosmeticsService)
local PetService = require(Services.PetService)
local RentalService = require(Services.RentalService)
local TutorialService = require(Services.TutorialService)
local XpService = require(Services.XpService)
local WheelService = require(Services.WheelService)
local GoldenHourService = require(Services.GoldenHourService)
local GiftService = require(Services.GiftService)
local CodeService = require(Services.CodeService)

local DebugService = {}

local COMMANDS = { "addCoins", "spendCoins", "save", "reset", "spawnDirt", "home", "skipTime", "unlockLevels", "rareContract", "breakFixture", "pests", "event", "newDay", "leaderboard", "setMonth", "addTokens", "fakeReceipt", "grantPass", "ride", "resetPets", "jobCutscene", "monthUnlock", "tutorial", "addXp", "wheelSpin", "goldenHour", "resetLevel", "giftTime", "resetGifts" }

local function handle(player: Player, command: any, arg: any)
	if not RunService:IsStudio() then
		return
	end
	if not RemoteService.IsOneOf(command, COMMANDS) then
		return
	end

	if command == "tutorial" then
		TutorialService.Restart(player)
		return
	end

	if command == "addXp" then
		if RemoteService.IsInteger(arg, 1, 100000) then
			XpService.Add(player, arg, "debug")
		end
		return
	elseif command == "wheelSpin" then
		WheelService.DebugAddSpin(player)
		return
	elseif command == "goldenHour" then
		GoldenHourService.StartNow()
		return
	elseif command == "giftTime" then
		if RemoteService.IsInteger(arg, 1, 3600) then
			GiftService.DebugAddTime(player, arg)
		end
		return
	elseif command == "resetGifts" then
		GiftService.DebugReset(player)
		CodeService.DebugReset(player)
		return
	elseif command == "resetLevel" then
		local data = DataService.Get(player)
		if data then
			data.level = 1
			data.xp = 0
			data.wheel.day = 0
			StateService.Push(player)
		end
		return
	end

	if command == "monthUnlock" then
		-- Start miesiąca arg tak, jakby gracz doszedł do niego pierwszy raz (prawdziwa ścieżka AdvanceMonth
		-- z cut scenami nowych prac); potem przywraca wcześniejszy najwyższy miesiąc, żeby nic się nie zablokowało
		if not RemoteService.IsInteger(arg, 2, 12) then
			return
		end
		local data = DataService.Get(player)
		if data then
			local highest = data.highestMonth
			data.month = arg - 1
			data.highestMonth = arg - 1
			MonthService.AdvanceMonth(player)
			data.highestMonth = math.max(highest, data.highestMonth)
			StateService.Push(player)
		end
		return
	end

	if command == "jobCutscene" then
		-- Podgląd cut sceny odblokowania pracy (arg = jobId)
		if RemoteService.IsString(arg, 32) then
			RemoteService.Event(RemoteNames.Events.JobUnlocked):FireClient(player, { arg })
		end
		return
	end

	if command == "addCoins" then
		if not RemoteService.IsInteger(arg, 1, 10000) then
			return
		end
		EconomyService.AddCoins(player, arg, "debug")
		StateService.Notify(player, "DEBUG: +" .. arg .. " monet", "good")
	elseif command == "spendCoins" then
		if not RemoteService.IsInteger(arg, 1, 10000) then
			return
		end
		if EconomyService.TrySpend(player, arg, "debug") then
			StateService.Notify(player, "DEBUG: wydano " .. arg .. " monet", "info")
		else
			StateService.Notify(player, "DEBUG: za mało monet na wydanie " .. arg, "bad")
		end
	elseif command == "save" then
		if not DataService.IsSaveable(player) then
			StateService.Notify(player, "DEBUG: DataStore niedostępny (dane tylko w tej sesji)", "warn")
		elseif DataService.SaveNow(player) then
			StateService.Notify(player, "DEBUG: zapisano", "good")
		else
			StateService.Notify(player, "DEBUG: zapis nieudany, sprawdź Output", "bad")
		end
	elseif command == "reset" then
		DataService.ResetData(player)
		StateService.Notify(player, "DEBUG: dane zresetowane", "warn")
	elseif command == "spawnDirt" then
		if not RemoteService.IsInteger(arg, 1, 20) then
			return
		end
		local added = ApartmentService.SpawnDirt(player, arg)
		StateService.Notify(player, "DEBUG: dodano brud x" .. added, "info")
	elseif command == "home" then
		ApartmentService.TeleportHome(player)
	elseif command == "skipTime" then
		if not RemoteService.IsInteger(arg, 1, 360) then
			return
		end
		MonthService.Skip(player, arg)
	elseif command == "unlockLevels" then
		local data = DataService.Get(player)
		if not data then
			return
		end
		for _, jobId in { "cleaner", "gardener", "cashier", "kebab", "pizza", "petsitter", "mechanic", "freelancer", "scrapPro" } do
			data.jobs[jobId] = { completions = 15, goodCount = 15, threeStarCount = 5 }
		end
		data.highestMonth = math.max(data.highestMonth, 8)
		StateService.Notify(player, "DEBUG: wszystkie prace i poziomy odblokowane", "good")
	elseif command == "rareContract" then
		RareContractService.ForceOffer(player)
	elseif command == "breakFixture" then
		FailureService.DebugBreak(player)
	elseif command == "pests" then
		FailureService.DebugPests(player)
	elseif command == "event" then
		if not RemoteService.IsInteger(arg, 1, 6) then
			return
		end
		EventService.DebugStart(player, arg)
	elseif command == "newDay" then
		ProgressService.DebugNewDay(player)
		StateService.Notify(player, "DEBUG: nowy dzień (nagroda i zadania od nowa)", "info")
	elseif command == "leaderboard" then
		LeaderboardService.DebugRefresh()
		StateService.Notify(player, "DEBUG: rankingi wysłane i pobrane", "info")
	elseif command == "fakeReceipt" then
		-- arg = numer zakupu; ten sam numer dwa razy = test ochrony przed podwójnym przyznaniem
		if not RemoteService.IsInteger(arg, 1, 1000000) then
			return
		end
		local decision = CosmeticsService.DebugReceipt(player, "debug-" .. arg)
		StateService.Notify(player, "DEBUG: paragon " .. arg .. " -> " .. decision, "info")
	elseif command == "addTokens" then
		local data = DataService.Get(player)
		if data then
			data.tokens += 100
			StateService.Push(player)
			StateService.Notify(player, "DEBUG: +100 kluczy", "good")
		end
	elseif command == "grantPass" then
		-- arg = "vip" albo "halloween": przyznaje Game Pass bez Robux (test strojów)
		if not RemoteService.IsOneOf(arg, { "vip", "halloween" }) then
			return
		end
		CosmeticsService.DebugGrantPass(player, arg)
		StateService.Notify(player, "DEBUG: przyznano pakiet " .. arg, "good")
	elseif command == "ride" then
		-- arg = nr stacji: teleport obok stacji i start jazdy (test bez klikania podpowiedzi)
		if not RemoteService.IsInteger(arg, 1, 6) then
			return
		end
		local station = RentalService.StationPosition(arg)
		if station and player.Character then
			player.Character:PivotTo(CFrame.new(station + Vector3.new(0, 3.5, 2)))
			task.wait(0.3)
			RentalService.StartRide(player, arg)
		end
	elseif command == "resetPets" then
		PetService.DebugReset(player)
		StateService.Notify(player, "DEBUG: zwierzaki usunięte", "warn")
	elseif command == "setMonth" then
		-- Przeskok do miesiąca (sprawdzanie przeprowadzek do lepszych mieszkań)
		if not RemoteService.IsInteger(arg, 1, 12) then
			return
		end
		local data = DataService.Get(player)
		if data then
			data.month = arg - 1
			MonthService.AdvanceMonth(player)
		end
	end
end

function DebugService.Init()
	if not (RunService:IsStudio() and GameConfig.DEBUG_IN_STUDIO) then
		return
	end
	RemoteService.OnServerEvent(RemoteNames.Events.DebugCommand, 5, handle)
	print("[DebugService] Komendy testowe włączone (Studio)")
end

return DebugService

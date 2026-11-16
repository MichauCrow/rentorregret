-- Punkt startowy serwera. Uruchamia serwisy w ustalonej kolejności:
-- najpierw Init() wszystkich (rejestracja), potem Start() wszystkich (praca).
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")
local World = ServerScriptService:WaitForChild("World")

require(World:WaitForChild("MapBuilder")).Build()

local ORDER = {
	"RemoteService",
	"DataService",
	"StateService",
	"EconomyService",
	"ApartmentService",
	"CleaningService",
	"MonthService",
	"JobService",
	"LandlordService",
	"RareContractService",
	"FailureService",
	"EventService",
	"CosmeticsService",
	"ShopService",
	"PetService",
	"RentalService",
	"HomeService",
	"RoommateService",
	"AchievementService",
	"ProgressService",
	"GoldenHourService",
	"XpService",
	"WheelService",
	"GiftService",
	"CodeService",
	"TutorialService",
	"LeaderboardService",
	"DebugService",
}

local modules = {}
for _, name in ORDER do
	modules[name] = require(Services:WaitForChild(name))
end

for _, name in ORDER do
	local module = modules[name]
	if module.Init then
		module.Init()
	end
end

for _, name in ORDER do
	local module = modules[name]
	if module.Start then
		module.Start()
	end
end

print("[Main] RENT OR REGRET: serwer gotowy")

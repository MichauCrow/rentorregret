-- Punkt startowy klienta: uruchamia kontrolery i łączy je z Remote'ami.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("Modules"):WaitForChild("RemoteNames"))
local Remotes = Shared:WaitForChild("Remotes")

local Controllers = script.Parent:WaitForChild("Controllers")
local HUDController = require(Controllers:WaitForChild("HUDController"))
local DebugPanelController = require(Controllers:WaitForChild("DebugPanelController"))
local CleanFxController = require(Controllers:WaitForChild("CleanFxController"))
local LandlordDialogController = require(Controllers:WaitForChild("LandlordDialogController"))
local JobUIController = require(Controllers:WaitForChild("JobUIController"))
local ShopController = require(Controllers:WaitForChild("ShopController"))
local RoommateController = require(Controllers:WaitForChild("RoommateController"))
local ProgressController = require(Controllers:WaitForChild("ProgressController"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local TutorialController = require(Controllers:WaitForChild("TutorialController"))
local LanguageController = require(Controllers:WaitForChild("LanguageController"))
local RepairController = require(Controllers:WaitForChild("RepairController"))
local SprintController = require(Controllers:WaitForChild("SprintController"))
local RidePoseController = require(Controllers:WaitForChild("RidePoseController"))
local GuideController = require(Controllers:WaitForChild("GuideController"))
local CutsceneController = require(Controllers:WaitForChild("CutsceneController"))
local PizzaMakerController = require(Controllers:WaitForChild("PizzaMakerController"))
local DoorController = require(Controllers:WaitForChild("DoorController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local ApartmentLightController = require(Controllers:WaitForChild("ApartmentLightController"))
local TrashSearchController = require(Controllers:WaitForChild("TrashSearchController"))
local PetController = require(Controllers:WaitForChild("PetController"))
local RentalController = require(Controllers:WaitForChild("RentalController"))
local BuildController = require(Controllers:WaitForChild("BuildController"))
local HomeController = require(Controllers:WaitForChild("HomeController"))
local EmoteController = require(Controllers:WaitForChild("EmoteController"))
local LevelController = require(Controllers:WaitForChild("LevelController"))
local WheelController = require(Controllers:WaitForChild("WheelController"))
local GoldenHourController = require(Controllers:WaitForChild("GoldenHourController"))
local GiftsController = require(Controllers:WaitForChild("GiftsController"))

local stateUpdate = Remotes:WaitForChild(RemoteNames.Events.StateUpdate)
local notify = Remotes:WaitForChild(RemoteNames.Events.Notify)
local getState = Remotes:WaitForChild(RemoteNames.Functions.GetState)
local cleanFx = Remotes:WaitForChild(RemoteNames.Events.CleanFx)
local landlordDialog = Remotes:WaitForChild(RemoteNames.Events.LandlordDialog)
local payRent = Remotes:WaitForChild(RemoteNames.Events.PayRent)
local payDebt = Remotes:WaitForChild(RemoteNames.Events.PayDebt)
local openJobMenu = Remotes:WaitForChild(RemoteNames.Events.OpenJobMenu)
local startJob = Remotes:WaitForChild(RemoteNames.Events.StartJob)
local cancelJob = Remotes:WaitForChild(RemoteNames.Events.CancelJob)
local jobAction = Remotes:WaitForChild(RemoteNames.Events.JobAction)
local jobUpdate = Remotes:WaitForChild(RemoteNames.Events.JobUpdate)
local jobResult = Remotes:WaitForChild(RemoteNames.Events.JobResult)
local getShop = Remotes:WaitForChild(RemoteNames.Functions.GetShop)
local buyItem = Remotes:WaitForChild(RemoteNames.Functions.BuyItem)
local goHome = Remotes:WaitForChild(RemoteNames.Events.GoHome)
local getSocial = Remotes:WaitForChild(RemoteNames.Functions.GetSocial)
local socialAction = Remotes:WaitForChild(RemoteNames.Events.SocialAction)
local socialState = Remotes:WaitForChild(RemoteNames.Events.SocialState)
local socialInvite = Remotes:WaitForChild(RemoteNames.Events.SocialInvite)
local getProgress = Remotes:WaitForChild(RemoteNames.Functions.GetProgress)
local claimDaily = Remotes:WaitForChild(RemoteNames.Functions.ClaimDaily)
local getLeaderboard = Remotes:WaitForChild(RemoteNames.Functions.GetLeaderboard)
local progressUpdate = Remotes:WaitForChild(RemoteNames.Events.ProgressUpdate)
local tutorialAction = Remotes:WaitForChild(RemoteNames.Events.TutorialAction)
local cosmeticAction = Remotes:WaitForChild(RemoteNames.Functions.CosmeticAction)
local repairGame = Remotes:WaitForChild(RemoteNames.Events.RepairGame)
local repairAction = Remotes:WaitForChild(RemoteNames.Events.RepairAction)
local furniturePlace = Remotes:WaitForChild(RemoteNames.Events.FurniturePlace)
local furnitureAction = Remotes:WaitForChild(RemoteNames.Events.FurnitureAction)
local trashGame = Remotes:WaitForChild(RemoteNames.Events.TrashGame)
local trashAction = Remotes:WaitForChild(RemoteNames.Events.TrashAction)
local getPets = Remotes:WaitForChild(RemoteNames.Functions.GetPets)
local buyPet = Remotes:WaitForChild(RemoteNames.Functions.BuyPet)
local petAction = Remotes:WaitForChild(RemoteNames.Events.PetAction)
local rentalAction = Remotes:WaitForChild(RemoteNames.Events.RentalAction)
local rentalState = Remotes:WaitForChild(RemoteNames.Events.RentalState)
local jobUnlocked = Remotes:WaitForChild(RemoteNames.Events.JobUnlocked)
local homeAction = Remotes:WaitForChild(RemoteNames.Functions.HomeAction)
local buildGame = Remotes:WaitForChild(RemoteNames.Events.BuildGame)
local buildAction = Remotes:WaitForChild(RemoteNames.Events.BuildAction)
local xpGain = Remotes:WaitForChild(RemoteNames.Events.XpGain)
local wheel = Remotes:WaitForChild(RemoteNames.Functions.Wheel)
local gifts = Remotes:WaitForChild(RemoteNames.Functions.Gifts)
local redeemCode = Remotes:WaitForChild(RemoteNames.Functions.RedeemCode)

local function invoke(remote: RemoteFunction, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	return if ok then result else nil
end

-- Najpierw język: od tej chwili każdy nowy tekst w interfejsie i świecie jest tłumaczony
LanguageController.Init()
SprintController.Init()
RidePoseController.Init()
GuideController.Init()
CutsceneController.Init()
jobUnlocked.OnClientEvent:Connect(CutsceneController.OnJobUnlocked)
DoorController.Init()
SoundController.Init()
TutorialController.Init({
	skip = function()
		tutorialAction:FireServer("skip")
	end,
	introDone = function()
		tutorialAction:FireServer("introDone")
	end,
	shopOpened = function()
		tutorialAction:FireServer("shopOpened")
	end,
})
HUDController.Init({
	onPayDebt = function()
		payDebt:FireServer()
	end,
	onShop = function()
		ShopController.Toggle()
	end,
	onHome = function()
		goHome:FireServer()
	end,
	onSocial = function()
		RoommateController.Toggle()
	end,
	onProgress = function()
		ProgressController.Toggle()
	end,
	onWheel = function()
		WheelController.Toggle()
	end,
})
EmoteController.Init()
LevelController.Init()
GoldenHourController.Init()
WheelController.Init({
	get = function()
		return invoke(wheel, "get")
	end,
	spin = function()
		return invoke(wheel, "spin")
	end,
	toast = function(text, kind)
		HUDController.Toast(text, kind)
	end,
})
xpGain.OnClientEvent:Connect(LevelController.OnXpGain)
GiftsController.Init({
	gifts = function(action, index)
		return invoke(gifts, action, index)
	end,
	redeem = function(text)
		return invoke(redeemCode, text)
	end,
})
ProgressController.Init({
	getProgress = function()
		return invoke(getProgress)
	end,
	claimDaily = function()
		return invoke(claimDaily)
	end,
	getLeaderboard = function()
		return invoke(getLeaderboard)
	end,
})
ShopController.Init({
	getShop = function()
		return invoke(getShop)
	end,
	buy = function(itemId)
		return invoke(buyItem, itemId)
	end,
	cosmetic = function(action, itemId)
		return invoke(cosmeticAction, action, itemId)
	end,
	promptProduct = function(productId)
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, productId)
	end,
	promptPass = function(passId)
		game:GetService("MarketplaceService"):PromptGamePassPurchase(game:GetService("Players").LocalPlayer, passId)
	end,
	openHome = function()
		HomeController.Open()
	end,
})
RoommateController.Init({
	getSocial = function()
		return invoke(getSocial)
	end,
	action = function(name, value)
		socialAction:FireServer(name, value)
	end,
})
RepairController.Init({
	send = function(failureId, action)
		repairAction:FireServer(failureId, action)
	end,
})
repairGame.OnClientEvent:Connect(RepairController.OnServer)
PlacementController.Init({
	send = function(index, action, x, z, rot)
		furnitureAction:FireServer(index, action, x, z, rot)
	end,
	toast = function(text, kind)
		HUDController.Toast(text, kind)
	end,
})
furniturePlace.OnClientEvent:Connect(PlacementController.Start)
ApartmentLightController.Init()
TrashSearchController.Init({
	send = function(action)
		trashAction:FireServer(action)
	end,
})
trashGame.OnClientEvent:Connect(TrashSearchController.OnServer)
PetController.Init({
	getPets = function()
		return invoke(getPets)
	end,
	buyPet = function(speciesId)
		return invoke(buyPet, speciesId)
	end,
	petAction = function(petId, command, power)
		petAction:FireServer(petId, command, power)
	end,
	toast = function(text, kind)
		HUDController.Toast(text, kind)
	end,
})
RentalController.Init({
	send = function(action, value)
		rentalAction:FireServer(action, value)
	end,
})
rentalState.OnClientEvent:Connect(RentalController.OnServer)
HomeController.Init({
	home = function(action, a, b, c)
		return invoke(homeAction, action, a, b, c)
	end,
	toast = function(text, kind)
		HUDController.Toast(text, kind)
	end,
})
BuildController.Init({
	send = function(action)
		buildAction:FireServer(action)
	end,
	toast = function(text, kind)
		HUDController.Toast(text, kind)
	end,
})
buildGame.OnClientEvent:Connect(BuildController.OnServer)
LandlordDialogController.Init(function()
	payRent:FireServer()
end)
JobUIController.Init({
	startJob = function(jobId, level)
		startJob:FireServer(jobId, level)
	end,
	cancelJob = function()
		cancelJob:FireServer()
	end,
	jobAction = function(action, value)
		jobAction:FireServer(action, value)
	end,
})
PizzaMakerController.Init({
	send = function(value)
		jobAction:FireServer("pizza", value)
	end,
})

if RunService:IsStudio() then
	DebugPanelController.Init(Remotes:WaitForChild(RemoteNames.Events.DebugCommand))
end

local lastCoins = nil
stateUpdate.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" and type(snapshot.coins) == "number" then
		if lastCoins and snapshot.coins > lastCoins then
			SoundController.Play("Coins")
		end
		lastCoins = snapshot.coins
	end
	HUDController.Update(snapshot)
	LevelController.ApplyState(snapshot)
	WheelController.ApplyState(snapshot)
	GiftsController.ApplyState(snapshot)
	ShopController.ApplyState(snapshot)
	ProgressController.ApplyState(snapshot)
	TutorialController.ApplyState(snapshot)
end)
progressUpdate.OnClientEvent:Connect(ProgressController.OnUpdate)
socialState.OnClientEvent:Connect(RoommateController.OnState)
socialInvite.OnClientEvent:Connect(RoommateController.ShowInvite)
notify.OnClientEvent:Connect(function(text, kind)
	HUDController.Toast(text, kind)
	SoundController.OnNotify(text, kind)
	if
		type(text) == "string"
		and (text:find("Czynsz zapłacony", 1, true) or text:find("Udało się w dogrywce", 1, true) or text:find("🏅", 1, true))
	then
		HUDController.Celebrate()
	end
end)
cleanFx.OnClientEvent:Connect(CleanFxController.Play)
openJobMenu.OnClientEvent:Connect(JobUIController.ShowMenu)
jobUpdate.OnClientEvent:Connect(function(payload)
	JobUIController.Update(payload)
	PizzaMakerController.Update(payload)
end)
jobResult.OnClientEvent:Connect(function(payload)
	JobUIController.ShowResult(payload)
	if type(payload) == "table" and (tonumber(payload.stars) or 0) >= 2 then
		SoundController.Play("Success")
	end
end)
landlordDialog.OnClientEvent:Connect(function(action, payload)
	if action == "open" then
		SoundController.Play("Doorbell")
		LandlordDialogController.Open(payload)
	elseif action == "close" then
		LandlordDialogController.Close()
	end
end)

-- Pierwszy stan: serwer może jeszcze wczytywać dane, więc ponawiamy pytanie
task.spawn(function()
	for _ = 1, 20 do
		local ok, snapshot = pcall(function()
			return getState:InvokeServer()
		end)
		if ok and snapshot then
			HUDController.Update(snapshot)
			LevelController.ApplyState(snapshot)
			GiftsController.ApplyState(snapshot)
			return
		end
		task.wait(1)
	end
end)

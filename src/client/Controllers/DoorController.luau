-- Drzwi mieszkań: na zewnątrz widać tylko "Wejdź", w środku tylko "Wyjdź".
-- Obie podpowiedzi siedzą na tych samych drzwiach, więc co chwilę sprawdzamy, po której stronie stoi gracz
-- (zewnątrz drzwi = lokalne -Z, tam jest OutsideAttachment). Zmiana Enabled działa tylko u tego gracza.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DoorController = {}

local CHECK_INTERVAL = 0.15
local NEAR_DISTANCE = 20

local function promptOf(door: BasePart, name: string): ProximityPrompt?
	local attachment = door:FindFirstChild(name)
	return attachment and attachment:FindFirstChildOfClass("ProximityPrompt")
end

local function update()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local apartments = Workspace:FindFirstChild("Apartments")
	if not root or not apartments then
		return
	end
	for _, apartment in apartments:GetChildren() do
		local door = apartment:FindFirstChild("Door")
		if door and door:IsA("BasePart") and (door.Position - root.Position).Magnitude <= NEAR_DISTANCE then
			local enter = promptOf(door, "OutsideAttachment")
			local exit = promptOf(door, "InsideAttachment")
			local outside = door.CFrame:PointToObjectSpace(root.Position).Z < 0
			if enter then
				enter.Enabled = outside
			end
			if exit then
				exit.Enabled = not outside
			end
		end
	end
end

function DoorController.Init()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			update()
		end
	end)
end

return DoorController

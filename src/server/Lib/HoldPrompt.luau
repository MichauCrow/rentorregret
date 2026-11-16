-- ProximityPrompt ze sprawdzaniem po stronie serwera: czas przytrzymania i odległość gracza.
-- onTriggered(player) jest wołane tylko wtedy, gdy oba warunki są spełnione.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JobsConfig = require(ReplicatedStorage.Shared.Config.JobsConfig)

local HoldPrompt = {}

-- options: action, object, hold (s), activation (zasięg podpowiedzi), maxDistance (serwer),
-- opcjonalnie onHoldBegan(player) / onHoldEnded(player): np. animacja i dźwięk w trakcie przytrzymania
function HoldPrompt.Create(parent: Instance, options, onTriggered): ProximityPrompt
	local hold = options.hold or 0
	local maxDistance = options.maxDistance or 10
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.action or ""
	prompt.ObjectText = options.object or ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = options.activation or 7
	prompt.RequiresLineOfSight = false

	local holdStarts = {}
	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdStarts[player] = os.clock()
		if options.onHoldBegan then
			options.onHoldBegan(player)
		end
	end)
	if options.onHoldEnded then
		prompt.PromptButtonHoldEnded:Connect(options.onHoldEnded)
		prompt.Triggered:Connect(options.onHoldEnded)
		prompt.Destroying:Connect(function()
			for player in holdStarts do
				options.onHoldEnded(player)
			end
		end)
	end
	prompt.Triggered:Connect(function(player)
		local started = holdStarts[player]
		holdStarts[player] = nil
		if hold > 0 and (not started or os.clock() - started < hold * JobsConfig.HOLD_TOLERANCE) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local origin = prompt.Parent
		if not root or not origin then
			return
		end
		local position = if origin:IsA("Attachment") then origin.WorldPosition elseif origin:IsA("BasePart") then origin.Position else nil
		if not position or (root.Position - position).Magnitude > maxDistance then
			return
		end
		onTriggered(player)
	end)
	prompt.Parent = parent
	return prompt
end

return HoldPrompt

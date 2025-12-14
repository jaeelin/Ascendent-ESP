local playerService = game:GetService("Players")
local runService = game:GetService("RunService")

local player = playerService.LocalPlayer

local camera = workspace.CurrentCamera

local AscendentESP = {}
AscendentESP.__index = AscendentESP

function AscendentESP.new(Config)
	local self = setmetatable({}, AscendentESP)

	self.enabled = false

	self.boxEnabled = Config and Config.Box or false
	self.healthBarEnabled = Config and Config.HealthBar or false
	self.tracerEnabled = Config and Config.Tracer or false
	self.skeletonEnabled = Config and Config.Skeleton or false
	self.nameEnabled = Config and Config.Name or false
	self.rainbowEnabled = Config and Config.Rainbow or false

	self.defaultColor = Config and Config.DefaultColor or Color3.fromRGB(250, 150, 255)
	self.targetColors = {}
	
	self.maxDistance = Config and Config.MaxDistance or 300

	self._skeletons = {}
	self._tracers = {}
	self._boxes = {}
	self._names = {}
	self._healthbars = {}
	
	self._activeTargets = {}

	self._connections = {}
	
	setmetatable(self, {
		__index = function(object, key)
			if key == "Box" then return object.boxEnabled end
			if key == "HealthBar" then return object.healthBarEnabled end
			if key == "Tracer" then return object.tracerEnabled end
			if key == "Skeleton" then return object.skeletonEnabled end
			if key == "Name" then return object.nameEnabled end
			if key == "Rainbow" then return object.rainbowEnabled end
			if key == "DefaultColor" then return object.defaultColor end
			if key == "MaxDistance" then return object.maxDistance end
			
			return rawget(AscendentESP, key)
		end,

		__newindex = function(object, key, value)
			if key == "Box" then object.boxEnabled = value return end
			if key == "HealthBar" then object.healthBarEnabled = value return end
			if key == "Tracer" then object.tracerEnabled = value return end
			if key == "Skeleton" then object.skeletonEnabled = value return end
			if key == "Name" then object.nameEnabled = value return end
			if key == "Rainbow" then object.rainbowEnabled = value return end
			if key == "DefaultColor" then object.defaultColor = value return end
			if key == "MaxDistance" then object.maxDistance = value return end
			
			rawset(object, key, value)
		end
	})

	return self
end

function AscendentESP:_createDrawing(type, properties)
	local drawing = Drawing.new(type)

	for property, value in next, properties do
		drawing[property] = value
	end

	return drawing
end

function AscendentESP:_getRainbow()
	local stored = tick()
	
	local hue = (math.sin(stored * 0.3) * 0.5 + 0.5)
	local saturation = 0.4 + 0.1 * math.sin(stored * 0.2 + 1)
	local value = 0.85 + 0.1 * math.sin(stored * 0.25 + 2)
	
	return Color3.fromHSV(hue, saturation, value)
end

function AscendentESP:_drawBone(target, index, pointA, pointB, color)
	if not pointA or not pointB then return end

	local pointAPosition, aOnScreen = camera:WorldToViewportPoint(pointA.Position)
	local pointBPosition, bOnScreen = camera:WorldToViewportPoint(pointB.Position)

	if aOnScreen and bOnScreen then
		self._skeletons[target] = self._skeletons[target] or {}
		self._skeletons[target][index] = self._skeletons[target][index] or self:_createDrawing("Line", {
			Thickness = 1.5,
			Color = color,
			Transparency = 1
		})
		
		local line = self._skeletons[target][index]
		line.From = Vector2.new(pointAPosition.X, pointAPosition.Y)
		line.To = Vector2.new(pointBPosition.X, pointBPosition.Y)
		line.Visible = true
	end
end

function AscendentESP:_cleanup(target)
	if self._boxes[target] then
		self._boxes[target].Visible = false
	end

	if self._healthbars[target] then
		self._healthbars[target].Visible = false
	end

	if self._tracers[target] then
		self._tracers[target].Visible = false
	end

	if self._names[target] then
		self._names[target].Visible = false
	end

	if self._skeletons[target] then
		for _, line in next, self._skeletons[target] do
			line.Visible = false
		end
	end
end

function AscendentESP:_removeESP()
	for _, table in next, {self._tracers, self._boxes, self._names, self._healthbars} do
		for _, object in next, table do
			if object then 
				object:Remove()
			end
		end
	end

	for _, skeleton in next, self._skeletons do
		for _, line in next, skeleton do
			if line then 
				line:Remove() 
			end
		end
	end

	self._tracers, self._boxes, self._names, self._healthbars, self._skeletons = {}, {}, {}, {}, {}
end

function AscendentESP:_drawBox(target, screenPosition, boxWidth, boxHeight, color)
	if not self.boxEnabled then
		if self._boxes[target] then
			self._boxes[target].Visible = false
		end

		return
	end

	self._boxes[target] = self._boxes[target] or self:_createDrawing("Square", {
		Color = color,
		Thickness = 1.5,
		Filled = false,
		Transparency = 1
	})
	
	self._boxes[target].Size = Vector2.new(boxWidth, boxHeight)
	self._boxes[target].Position = Vector2.new(screenPosition.X - boxWidth / 2, screenPosition.Y - boxHeight / 2)
	self._boxes[target].Color = color
	self._boxes[target].Visible = true
end

function AscendentESP:_drawHealthBar(target, screenPosition, boxWidth, boxHeight, color)
	if not self.healthBarEnabled then
		if self._healthbars and self._healthbars[target] then
			self._healthbars[target].Visible = false
		end
		
		return
	end
	
	self._healthbars[target] = self._healthbars[target] or self:_createDrawing("Square", {
		Color = color,
		Thickness = 1,
		Filled = true,
		Transparency = 1
	})
	
	local humanoid = target.Character and target.Character:FindFirstChild("Humanoid")
	if not humanoid then
		self._healthbars[target].Visible = false
		return
	end

	local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	
	local barX = screenPosition.X + (boxWidth / 2) + 4
	local barY = screenPosition.Y - boxHeight / 2 + (boxHeight * (1 - healthPercent))

	self._healthbars[target].Size = Vector2.new(3, boxHeight * healthPercent)
	self._healthbars[target].Position = Vector2.new(barX, barY)
	self._healthbars[target].Color = color
	self._healthbars[target].Visible = true
end

function AscendentESP:_drawTracer(target, screenPosition, color)
	if not self.tracerEnabled then
		if self._tracers[target] then
			self._tracers[target].Visible = false
		end
		return
	end

	self._tracers[target] = self._tracers[target] or self:_createDrawing("Line", {
		Color = color,
		Thickness = 1.5
	})

	local viewportSize = camera.ViewportSize
	local cameraScreenPosition = Vector2.new(
		viewportSize.X / 2,
		viewportSize.Y / 2
	)

	self._tracers[target].From = cameraScreenPosition
	self._tracers[target].To = Vector2.new(screenPosition.X, screenPosition.Y)
	self._tracers[target].Color = color
	self._tracers[target].Visible = true
end

function AscendentESP:_drawName(target, screenPosition, boxHeight, distance, color)
	if not self.nameEnabled then
		if self._names[target] then
			self._names[target].Visible = false
		end

		return
	end

	self._names[target] = self._names[target] or self:_createDrawing("Text", {
		Text = target.Name,
		Color = color,
		Font = 2,
		Size = 14,
		Center = true,
		Outline = true
	})

	self._names[target].Text = target.Name .. " [" .. distance .. "m]"
	self._names[target].Position = Vector2.new(screenPosition.X, screenPosition.Y - boxHeight / 2 - 15)
	self._names[target].Color = color
	self._names[target].Visible = true
end

function AscendentESP:_drawSkeleton(target, character, color)
	if not self.skeletonEnabled then return end

	local function getPart(part)
		return character:FindFirstChild(part)
	end

	local torso = getPart("Torso") or getPart("UpperTorso")
	local lowerTorso = getPart("LowerTorso")
	local root = torso or lowerTorso

	local parts = {
		Head = getPart("Head"),
		Torso = torso,
		LowerTorso = lowerTorso,
		LeftUpperArm = getPart("Left Arm") or getPart("LeftUpperArm"),
		RightUpperArm = getPart("Right Arm") or getPart("RightUpperArm"),
		LeftLowerArm = getPart("LeftLowerArm"),
		RightLowerArm = getPart("RightLowerArm"),
		LeftUpperLeg = getPart("Left Leg") or getPart("LeftUpperLeg"),
		RightUpperLeg = getPart("Right Leg") or getPart("RightUpperLeg"),
		LeftLowerLeg = getPart("LeftLowerLeg"),
		RightLowerLeg = getPart("RightLowerLeg")
	}

	self:_drawBone(target, 1, parts.Head, root, color)

	if parts.LeftUpperArm then
		self:_drawBone(target, 2, root, parts.LeftUpperArm, color)

		if parts.LeftLowerArm then self:_drawBone(target, 3, parts.LeftUpperArm, parts.LeftLowerArm, color) end
	end

	if parts.RightUpperArm then
		self:_drawBone(target, 4, root, parts.RightUpperArm, color)

		if parts.RightLowerArm then self:_drawBone(target, 5, parts.RightUpperArm, parts.RightLowerArm, color) end
	end

	if parts.LeftUpperLeg then
		self:_drawBone(target, 6, root, parts.LeftUpperLeg, color)

		if parts.LeftLowerLeg then self:_drawBone(target, 7, parts.LeftUpperLeg, parts.LeftLowerLeg, color) end
	end

	if parts.RightUpperLeg then
		self:_drawBone(target, 8, root, parts.RightUpperLeg, color)

		if parts.RightLowerLeg then self:_drawBone(target, 9, parts.RightUpperLeg, parts.RightLowerLeg, color) end
	end

	for _, line in next, self._skeletons[target] or {} do
		line.Color = color
	end
end

function AscendentESP:_updateTargetESP(target)
	local character = target.Character
	if not character or not character.Parent then
		self:_cleanup(target)
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
		self:_cleanup(target)
		return
	end

	local color = self.targetColors[target] or self.defaultColor
	if self.rainbowEnabled then
		color = self:_getRainbow()
	end

	local headPosition, headOnScreen = camera:WorldToViewportPoint(
		humanoidRootPart.Position + Vector3.new(0, 3, 0)
	)
	local footPosition, footOnScreen = camera:WorldToViewportPoint(
		humanoidRootPart.Position - Vector3.new(0, 3, 0)
	)

	if not (headOnScreen or footOnScreen) then
		self:_cleanup(target)
		return
	end

	local boxHeight = footPosition.Y - headPosition.Y
	local boxWidth = boxHeight / 1.5
	local boxCenter = Vector2.new(
		(headPosition.X + footPosition.X) / 2,
		(headPosition.Y + footPosition.Y) / 2
	)

	local distance = 0
	local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if localRoot then
		distance = math.floor((localRoot.Position - humanoidRootPart.Position).Magnitude)
	end

	if self.maxDistance > 0 and distance > self.maxDistance then
		self:_cleanup(target)
		return
	end

	self:_drawBox(target, boxCenter, boxWidth, boxHeight, color)
	self:_drawHealthBar(target, boxCenter, boxWidth, boxHeight, color)
	self:_drawTracer(target, boxCenter, color)
	self:_drawName(target, boxCenter, boxHeight, distance, color)
	self:_drawSkeleton(target, character, color)
end

function AscendentESP:setupESP(target)
	if target == player then return end
	
	self._activeTargets[target] = true

	if not self._renderConnection then
		self._renderConnection = runService.RenderStepped:Connect(function()
			if not self.enabled then return end
			
			for activeTarget in next, self._activeTargets do
				self:_updateTargetESP(activeTarget)
			end
		end)
		
		table.insert(self._connections, self._renderConnection)
	end
end

function AscendentESP:SetColor(targetPlayer, color)
	self.targetColors[targetPlayer] = color
end

function AscendentESP:Enable()
	self.enabled = true

	for _, target in next, playerService:GetPlayers() do
		self:setupESP(target)
	end

	table.insert(self._connections, playerService.PlayerAdded:Connect(function(target)
		self:setupESP(target)
	end))
	
	table.insert(self._connections, playerService.PlayerRemoving:Connect(function(target)
		self._activeTargets[target] = nil
		self:_cleanup(target)
	end))
end

function AscendentESP:Disable()
	self.enabled = false

	if self._activeTargets then
		for target in next, self._activeTargets do
			self:_cleanup(target)
		end
	end

	self:_removeESP()

	for _, connection in next, self._connections do
		connection:Disconnect()
	end

	self._connections = {}
end

return AscendentESP

local playerService = game:GetService("Players")
local runService = game:GetService("RunService")

local player = playerService.LocalPlayer

local camera = workspace.CurrentCamera

local AscendentESP = {}
AscendentESP.__index = AscendentESP

function AscendentESP.new(Config)
	local self = setmetatable({}, AscendentESP)

	self.enabled = false

	self.Box = Config and Config.Box or false
	self.HealthBar = Config and Config.HealthBar or false
	self.TracerEnabled = Config and Config.Tracer or false
	self.Skeleton = Config and Config.Skeleton or false
	self.Name = Config and Config.Name or false
	self.Arrows = Config and Config.Arrows or false
	self.Rainbow = Config and Config.Rainbow or false

	self.DefaultColor = Config and Config.DefaultColor or Color3.fromRGB(250, 150, 255)
	self.targetColors = {}
	
	self.MaxDistance = Config and Config.MaxDistance or 300

	self._boxes = {}
	self._healthbars = {}
	self._tracers = {}
	self._skeletons = {}
	self._names = {}
	self._arrows = {}
	
	self._activeTargets = {}

	self._connections = {}

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
	for _, table in next, {self._boxes, self._healthbars, self._tracers, self._names, self._arrows} do
		if table[target] then
			if type(table[target]) == "table" then
				for _, obj in next, table[target] do 
					obj.Visible = false 
				end
			else
				table[target].Visible = false
			end
		end
	end
	
	if self._skeletons[target] then
		for _, line in next, self._skeletons[target] do 
			line.Visible = false 
		end
	end
end

function AscendentESP:_removeESP()
	local allTables = {self._tracers, self._boxes, self._names, self._healthbars, self._arrows}

	for _, table in next, allTables do
		for _, object in next, table do
			if type(object) == "table" then
				for _, subObject in next, object do
					subObject.Visible = false
				end
			elseif object then
				object.Visible = false
			end
		end
	end

	for _, skeleton in next, self._skeletons do
		for _, line in next, skeleton do
			line.Visible = false
		end
	end

	self._tracers, self._boxes, self._names, self._healthbars, self._skeletons, self._arrows = {}, {}, {}, {}, {}, {}
end

function AscendentESP:_drawBox(target, screenPosition, boxWidth, boxHeight, color)
	if not self.Box then
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
	if not self.HealthBar then
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
	if not self.TracerEnabled then
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
	if not self.Name then
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
	if not self.Skeleton then
		for _, skeleton in next, self._skeletons do
			for _, line in next, skeleton do
				line.Visible = false
			end
		end

		return
	end

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

function AscendentESP:_drawArrows(target, screenPos, color)
	if not self.Arrows then
		if self._arrows[target] then
			for _, line in next, self._arrows[target] do
				line.Visible = false
			end
		end
		
		return
	end
	
	local character = target.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	
	self._arrows[target] = self._arrows[target] or {}
	
	local viewportSize = camera.ViewportSize
	local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	
	local directionVector = screenPos - screenCenter
	
	local toTarget = (character.HumanoidRootPart.Position - camera.CFrame.Position).Unit
	if camera.CFrame.LookVector:Dot(toTarget) < 0 then
		directionVector = -directionVector
	end
	
	local directionUnit = directionVector.Unit
	
	local edgePadding = 20
	local halfScreenX, halfScreenY = viewportSize.X / 2 - edgePadding, viewportSize.Y / 2 - edgePadding
	
	local scaleX = halfScreenX / math.abs(directionUnit.X)
	local scaleY = halfScreenY / math.abs(directionUnit.Y)
	local scale = math.min(scaleX, scaleY)
	
	local arrowPos = screenCenter + directionUnit * scale
	
	local arrowSize = 10
	local angle = math.atan2(directionUnit.Y, directionUnit.X)
	local point1 = arrowPos + Vector2.new(math.cos(angle) * arrowSize, math.sin(angle) * arrowSize)
	local point2 = arrowPos + Vector2.new(math.cos(angle + 2.5) * arrowSize, math.sin(angle + 2.5) * arrowSize)
	local point3 = arrowPos + Vector2.new(math.cos(angle - 2.5) * arrowSize, math.sin(angle - 2.5) * arrowSize)
	
	for i, point in next, {point1, point2, point3} do
		self._arrows[target][i] = self._arrows[target][i] or self:_createDrawing("Line", {
			Color = color,
			Thickness = 1.5
		})
	end
	
	self._arrows[target][1].From, self._arrows[target][1].To = point1, point2
	self._arrows[target][2].From, self._arrows[target][2].To = point2, point3
	self._arrows[target][3].From, self._arrows[target][3].To = point3, point1
	
	for _, line in next, self._arrows[target] do
		line.Color = color
		line.Visible = true
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

	local color = self.targetColors[target] or self.DefaultColor
	if self.Rainbow then
		color = self:_getRainbow()
	end

	local headPosition, headOnScreen = camera:WorldToViewportPoint(
		humanoidRootPart.Position + Vector3.new(0, 3, 0)
	)
	local footPosition, footOnScreen = camera:WorldToViewportPoint(
		humanoidRootPart.Position - Vector3.new(0, 3, 0)
	)

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

	if self.MaxDistance > 0 and distance > self.MaxDistance then
		self:_cleanup(target)
		return
	end
	
	if not (headOnScreen or footOnScreen) then
		self:_cleanup(target)
		self:_drawArrows(target, boxCenter, color)
		return
	else
		if self._arrows[target] then
			for _, line in next, self._arrows[target] do
				line.Visible = false
			end
		end
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

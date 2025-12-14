local playerService = game:GetService("Players")
local runService = game:GetService("RunService")

local player = playerService.LocalPlayer

local camera = workspace.CurrentCamera

local AscendentESP = {}
AscendentESP.__index = AscendentESP

function AscendentESP.new()
	local self = setmetatable({}, AscendentESP)

	self.enabled = false

	self.boxEnabled = false
	self.tracerEnabled = false
	self.skeletonEnabled = false
	self.nameEnabled = false
	self.rainbowEnabled = false

	self.defaultColor = Color3.fromRGB(250, 150, 255)
	self.targetColors = {}

	self._skeletons = {}
	self._tracers = {}
	self._boxes = {}
	self._names = {}
	self._healthbars = {}

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
	local speed = 0.25
	local hue = (tick() * speed) % 1
	local saturation = 0.8 + 0.2 * math.sin(tick() * speed)
	local value = 0.9 + 0.1 * math.cos(tick() * speed)

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
	local objects = {self._boxes, self._tracers, self._names, self._healthbars}

	for _, table in next, objects do
		local object = table[target]

		if object then
			object:Remove()
			table[target] = nil
		end
	end

	local skeleton = self._skeletons[target]

	if skeleton then
		for _, line in next, skeleton do
			if line then 
				line:Remove() 
			end
		end

		self._skeletons[target] = nil
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
		Transparency = 1,
		Filled = false
	})

	self._boxes[target].Size = Vector2.new(boxWidth, boxHeight)
	self._boxes[target].Position = Vector2.new(screenPosition.X - boxWidth / 2, screenPosition.Y - boxHeight / 2)
	self._boxes[target].Color = color
	self._boxes[target].Visible = true
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

	self._tracers[target].From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
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

function AscendentESP:setupESP(target)
	if target == player then return end

	local function setupCharacter()
		runService.RenderStepped:Connect(function()
			if not self.enabled then return end

			local character = target.Character
			if not character or not character.Parent then self:_cleanup(target) return end

			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then return end

			local humanoid = character:FindFirstChild("Humanoid")
			if not humanoid or humanoid.Health <= 0 then self:_cleanup(target) return end

			local color = self.targetColors[target] or self.defaultColor
			if self.rainbowEnabled then color = self:_getRainbow() end

			local screenPosition, onScreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
			local headPosition = camera:WorldToViewportPoint(humanoidRootPart.Position + Vector3.new(0, 3, 0))
			local footPosition = camera:WorldToViewportPoint(humanoidRootPart.Position - Vector3.new(0, 3, 0))
			local boxHeight = footPosition.Y - headPosition.Y
			local boxWidth = boxHeight / 1.5
			local distance = math.floor((camera.CFrame.Position - humanoidRootPart.Position).Magnitude)

			if onScreen then
				self:_drawBox(target, screenPosition, boxWidth, boxHeight, color)
				self:_drawTracer(target, screenPosition, color)
				self:_drawName(target, screenPosition, boxHeight, distance, color)
				self:_drawSkeleton(target, character, color)
			else
				self:_cleanup(target)
			end
		end)
	end

	if target.Character then setupCharacter() end

	target.CharacterAdded:Connect(setupCharacter)
end

function AscendentESP:SetColor(targetPlayer, color)
	self.targetColors[targetPlayer] = color
end

function AscendentESP:Enable()
	self.enabled = true

	for _, target in next, playerService:GetPlayers() do
		self:setupESP(target)
	end

	self._connections = self._connections or {}

	table.insert(self._connections, playerService.PlayerAdded:Connect(function(target)
		self:setupESP(target)
	end))
end

function AscendentESP:Disable()
	self.enabled = false
	self:_removeESP()

	if self._connections then
		for _, connection in next, self._connections do
			connection:Disconnect()
		end

		self._connections = nil
	end
end

return AscendentESP

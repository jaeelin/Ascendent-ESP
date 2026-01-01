local playerService = game:GetService("Players")
local runService = game:GetService("RunService")

local player = playerService.LocalPlayer

local camera = workspace.CurrentCamera

local ObjectESP = {}
ObjectESP.__index = ObjectESP

ObjectESP.Version = "1.0.1"

function ObjectESP.new(Config)
	local self = setmetatable({}, ObjectESP)

	self.enabled = false
	
	self.Box = Config and Config.Box or false
	self.Tracer = Config and Config.Tracer or false
	self.Name = Config and Config.Name or false
	self.Rainbow = Config and Config.Rainbow or false
	
	self.TracerOrigin = Config and Config.TracerOrigin or "Character"

	self.DefaultColor = Config and Config.DefaultColor or Color3.fromRGB(255, 255, 255)

	self.MaxDistance = Config and Config.MaxDistance or 300
	
	self._boxes = {}
	self._tracers = {}
	self._names = {}
	
	self.objectColors = {}

	self._trackedObjects = {}

	self._connections = {}

	return self
end

function ObjectESP:_createDrawing(type, properties)
	local drawing = Drawing.new(type)

	for property, value in next, properties do
		drawing[property] = value
	end

	return drawing
end

function ObjectESP:_getRainbow()
	local stored = tick()

	local hue = (math.sin(stored * 0.3) * 0.5 + 0.5)
	local saturation = 0.4 + 0.1 * math.sin(stored * 0.2 + 1)
	local value = 0.85 + 0.1 * math.sin(stored * 0.25 + 2)

	return Color3.fromHSV(hue, saturation, value)
end

function ObjectESP:_cleanup(object)
	local tables = {self._boxes, self._tracers, self._names}

	for _, drawingTable in next, tables do
		local drawingObject = drawingTable[object]

		if drawingObject then
			drawingObject:Remove()
			drawingTable[object] = nil
		end
	end
end

function ObjectESP:_removeESP()
	for _, table in next, {self._tracers, self._boxes, self._names} do
		for _, object in next, table do
			if object then 
				object:Remove()
			end
		end
	end

	self._tracers, self._boxes, self._names = {}, {}, {}
end

function ObjectESP:_drawBox(object, screenPosition, size, color)
	if not self.Box then
		if self._boxes[object] then self._boxes[object].Visible = false end
		return
	end

	self._boxes[object] = self._boxes[object] or self:_createDrawing("Square", {
		Color = color,
		Thickness = 1.5,
		Transparency = 1,
		Filled = false
	})

	self._boxes[object].Size = size
	self._boxes[object].Position = Vector2.new(screenPosition.X - size.X / 2, screenPosition.Y - size.Y / 2)
	self._boxes[object].Color = color
	self._boxes[object].Visible = true
end

function ObjectESP:_drawTracer(object, screenPosition, color)
	if not self.Tracer then
		if self._tracers[object] then
			self._tracers[object].Visible = false
		end
		return
	end

	self._tracers[object] = self._tracers[object] or self:_createDrawing("Line", {
		Color = color,
		Thickness = 1.5
	})

	local viewportSize = camera.ViewportSize
	local cameraScreenPosition

	if self.TracerOrigin == "Character" then
		cameraScreenPosition = Vector2.new(
			viewportSize.X / 2,
			viewportSize.Y / 2
		)
	elseif self.TracerOrigin == "Top" then
		cameraScreenPosition = Vector2.new(
			viewportSize.X / 2,
			0
		)
	elseif self.TracerOrigin == "Bottom" then
		cameraScreenPosition = Vector2.new(
			viewportSize.X / 2,
			viewportSize.Y
		)
	else
		cameraScreenPosition = Vector2.new(
			viewportSize.X / 2,
			viewportSize.Y / 2
		)
	end

	self._tracers[object].From = cameraScreenPosition
	self._tracers[object].To = Vector2.new(screenPosition.X, screenPosition.Y)
	self._tracers[object].Color = color
	self._tracers[object].Visible = true
end

function ObjectESP:_drawName(object, screenPosition, size, distance, color)
	if not self.Name then
		if self._names[object] then self._names[object].Visible = false end
		return
	end

	self._names[object] = self._names[object] or self:_createDrawing("Text", {
		Text = object.Name,
		Color = color,
		Font = 2,
		Size = 14,
		Center = true,
		Outline = true
	})

	self._names[object].Text = object.Name .. " [" .. distance .. "m]"
	self._names[object].Position = screenPosition + Vector2.new(0, -size.Y/2 - 5)
	self._names[object].Color = color
	self._names[object].Visible = true
end

function ObjectESP:_getScreenBox(object)
	local objectCFrame = object.CFrame
	local objectSize = object.Size

	local offsets = {-0.5, 0.5}
	local corners = {}

	for _, xMultiplier in next, offsets do
		for _, yMultiplier in next, offsets do
			for _, zMultiplier in next, offsets do
				table.insert(corners, objectCFrame * Vector3.new(objectSize.X * xMultiplier, objectSize.Y * yMultiplier, objectSize.Z * zMultiplier))
			end
		end
	end

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge

	for _, corner in next, corners do
		local screenPosition, onScreen = camera:WorldToViewportPoint(corner)

		if onScreen then
			minX = math.min(minX, screenPosition.X)
			minY = math.min(minY, screenPosition.Y)
			maxX = math.max(maxX, screenPosition.X)
			maxY = math.max(maxY, screenPosition.Y)
		end
	end

	if minX == math.huge then
		return Vector2.new(0, 0), Vector2.new(0, 0)
	end

	return Vector2.new(maxX - minX, maxY - minY), Vector2.new((minX + maxX)/2, (minY + maxY)/2)
end

function ObjectESP:_renderESP()
	self._connections = self._connections or {}

	local connection = runService.RenderStepped:Connect(function()
		if not self.enabled then return end
		if not self._trackedObjects then return end

		local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

		for i = #self._trackedObjects, 1, -1 do
			local object = self._trackedObjects[i]

			if not object or not object.Parent then
				self:_cleanup(object)
				table.remove(self._trackedObjects, i)
				continue
			end

			local color = self.objectColors[object] or self.DefaultColor
			if self.Rainbow then
				color = self:_getRainbow()
			end

			local size, screenPosition = self:_getScreenBox(object)

			local distance = 0
			if humanoidRootPart then
				distance = math.floor((humanoidRootPart.Position - object.Position).Magnitude)
			end

			if self.MaxDistance > 0 and distance > self.MaxDistance then
				self:_cleanup(object)
				continue
			end

			if size.X > 0 and size.Y > 0 then
				self:_drawBox(object, screenPosition, size, color)
				self:_drawTracer(object, screenPosition, color)
				self:_drawName(object, screenPosition, size, distance, color)
			else
				self:_cleanup(object)
			end
		end
	end)

	table.insert(self._connections, connection)
end

function ObjectESP:SetColor(objects, color)
	if typeof(objects) ~= "table" then
		objects = {objects}
	end

	for _, object in next, objects do
		self.objectColors[object] = color
	end
end

function ObjectESP:Setup(objects)
	if typeof(objects) ~= "table" then
		objects = {objects}
	end

	for _, object in next, objects do
		if not table.find(self._trackedObjects, object) then
			table.insert(self._trackedObjects, object)
		end
	end
end

function ObjectESP:Enable()
	self.enabled = true

	if not self._connections or #self._connections == 0 then
		self:_renderESP()
	end
end

function ObjectESP:Disable()
	self.enabled = false
	self:_removeESP()

	if self._connections then
		for _, connection in next, self._connections do
			connection:Disconnect()
		end

		self._connections = nil
	end
end

return ObjectESP

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
	self.nameEnabled = false
	self.rainbowEnabled = false

	self.defaultColor = Color3.fromRGB(250, 150, 255)
	self.objectColors = {}

	self._tracers = {}
	self._boxes = {}
	self._names = {}

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
	local speed = 0.25
	local hue = (tick() * speed) % 1
	local saturation = 0.8 + 0.2 * math.sin(tick() * speed)
	local value = 0.9 + 0.1 * math.cos(tick() * speed)

	return Color3.fromHSV(hue, saturation, value)
end

function AscendentESP:_cleanup(object)
	local tables = {self._boxes, self._tracers, self._names}

	for _, drawingTable in next, tables do
		local drawingObject = drawingTable[object]

		if drawingObject then
			drawingObject:Remove()
			drawingTable[object] = nil
		end
	end
end

function AscendentESP:_removeESP()
	for _, table in next, {self._tracers, self._boxes, self._names} do
		for _, object in next, table do
			if object then 
				object:Remove()
			end
		end
	end

	self._tracers, self._boxes, self._names = {}, {}, {}
end

function AscendentESP:_drawBox(obj, screenPos, size, color)
	if not self.boxEnabled then
		if self._boxes[obj] then self._boxes[obj].Visible = false end
		return
	end

	self._boxes[obj] = self._boxes[obj] or self:_createDrawing("Square", {
		Color = color,
		Thickness = 1.5,
		Transparency = 1,
		Filled = false
	})
	self._boxes[obj].Size = size
	self._boxes[obj].Position = Vector2.new(screenPos.X - size.X/2, screenPos.Y - size.Y/2)
	self._boxes[obj].Color = color
	self._boxes[obj].Visible = true
end

function AscendentESP:_drawTracer(obj, screenPos, color)
	if not self.tracerEnabled then
		if self._tracers[obj] then self._tracers[obj].Visible = false end
		return
	end

	self._tracers[obj] = self._tracers[obj] or self:_createDrawing("Line", {
		Color = color,
		Thickness = 1.5
	})
	
	local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local startPosition3D = humanoidRootPart.Position
		local startPosition2D, onScreenStart = camera:WorldToViewportPoint(startPosition3D)

		if onScreenStart then
			self._tracers[obj].From = Vector2.new(startPosition2D.X, startPosition2D.Y)
			self._tracers[obj].To = screenPos
			self._tracers[obj].Color = color
			self._tracers[obj].Visible = true
			return
		end
	end
	self._tracers[obj].Visible = false
end

function AscendentESP:_drawName(obj, screenPos, size, color)
	if not self.nameEnabled then
		if self._names[obj] then self._names[obj].Visible = false end
		return
	end

	self._names[obj] = self._names[obj] or self:_createDrawing("Text", {
		Text = obj.Name,
		Color = color,
		Font = 2,
		Size = 14,
		Center = true,
		Outline = true
	})

	self._names[obj].Text = obj.Name
	self._names[obj].Position = screenPos + Vector2.new(0, -size.Y/2 - 5)
	self._names[obj].Color = color
	self._names[obj].Visible = true
end

function AscendentESP:_getScreenBox(object)
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
		return Vector2.new(0, 0)
	end

	return Vector2.new(maxX - minX, maxY - minY), Vector2.new((minX + maxX)/2, (minY + maxY)/2)
end

function AscendentESP:_trackObject(object)
	local connection
	connection = runService.RenderStepped:Connect(function()
		if not self.enabled then
			if connection then 
				connection:Disconnect() 
			end
			return
		end

		if not object or not object.Parent then
			self:_cleanup(object)
			return
		end

		local color = self.objectColors[object] or self.defaultColor
		if self.rainbowEnabled then
			color = self:_getRainbow()
		end

		local size, screenPosition = self:_getScreenBox(object)

		if size.X > 0 and size.Y > 0 then
			self:_drawBox(object, screenPosition, size, color)
			self:_drawTracer(object, screenPosition, color)
			self:_drawName(object, screenPosition, size, color)
		else
			self:_cleanup(object)
		end
	end)

	table.insert(self._connections, connection)
end

function AscendentESP:SetColor(objects, color)
	if typeof(objects) ~= "table" then
		objects = {objects}
		self.objectColors[objects] = color
	end

	for _, object in next, objects do
		self.objectColors[object] = color
	end
end

function AscendentESP:Setup(objects)
	if typeof(objects) ~= "table" then
		objects = {objects}
	end
	
	for _, object in next, objects do
		self:_trackObject(object)
	end
end

function AscendentESP:Enable()
	self.enabled = true
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

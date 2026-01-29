local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Camera = workspace.CurrentCamera

local ObjectESP = {}
ObjectESP.__index = ObjectESP
ObjectESP.Version = "1.0.1"

function ObjectESP.new(config)
	local self = setmetatable({}, ObjectESP)
	
	self.Enabled = false
	
	self.Box = config and config.box or false
	self.Tracer = config and config.tracer or false
	self.Name = config and config.name or false
	self.Rainbow = config and config.rainbow or false
	self.TracerOrigin = config and config.tracer_origin or "Character"
	self.DefaultColor = config and config.default_color or Color3.fromRGB(255, 255, 255)
	self.MaxDistance = config and config.max_distance or 300
	
	self._boxes = {}
	self._tracers = {}
	self._names = {}
	
	self.__object_colors = {}
	self._tracked_objects = {}
	self._connections = {}
	
	return self
end

function ObjectESP:CreateDrawing(Type: string, Properties: {any})
	local drawing = Drawing.new(Type)

	for property, value in next, Properties do
		drawing[property] = value
	end

	return drawing
end

function ObjectESP:GetRainbow()
	local current_time = tick() * 0.5
	local hue = (current_time * 0.35) % 1

	local saturation = 0.9
	local value = 0.9

	return Color3.fromHSV(hue, saturation, value)
end

function ObjectESP:Cleanup(object: BasePart)
	if not object then return end

	local tables = {
		self._boxes,
		self._tracers,
		self._names
	}

	for _, drawing_table in next, tables do
		local drawing = drawing_table[object]
		if drawing then
			drawing:Remove()
			drawing_table[object] = nil
		end
	end
end

function ObjectESP:Remove()
	for _, table in next, { self._tracers, self._boxes, self._names } do
		for key, obj in next, table do
			if typeof(obj) == "table" then
				for _, sub in next, obj do
					if sub then
						sub:Remove()
					end
				end
			elseif obj then
				obj:Remove()
			end
			
			table[key] = nil
		end
	end

	self._tracers = {}
	self._boxes = {}
	self._names = {}
end

function ObjectESP:DrawBox(Object: BasePart, ScreenPosition: Vector2, Size: Vector2, Color: Color3)
	if not self.Box then
		if self._boxes[Object] then
			self._boxes[Object].Visible = false
		end
		
		return
	end

	self._boxes[Object] = self._boxes[Object] or self:CreateDrawing("Square", {
		Color = Color,
		Thickness = 1.5,
		Transparency = 1,
		Filled = false
	})

	local box = self._boxes[Object]
	box.Size = Size
	box.Position = Vector2.new(
		ScreenPosition.X - Size.X / 2,
		ScreenPosition.Y - Size.Y / 2
	)
	box.Color = Color
	box.Visible = true
end

function ObjectESP:DrawTracer(Object: BasePart, ScreenPosition: Vector2, Color: Color3)
	if not self.Tracer then
		if self._tracers[Object] then
			self._tracers[Object].Visible = false
		end
		return
	end

	self._tracers[Object] = self._tracers[Object] or self:CreateDrawing("Line", {
		Color = Color,
		Thickness = 1.5
	})

	local tracer = self._tracers[Object]
	local viewport_size = Camera.ViewportSize

	local camera_screen_position
	if self.TracerOrigin == "Origin" then
		camera_screen_position = Vector2.new(viewport_size.X / 2, viewport_size.Y / 2)
	elseif self.TracerOrigin == "Top" then
		camera_screen_position = Vector2.new(viewport_size.X / 2, 0)
	elseif self.TracerOrigin == "Bottom" then
		camera_screen_position = Vector2.new(viewport_size.X / 2, viewport_size.Y)
	else
		camera_screen_position = Vector2.new(viewport_size.X / 2, viewport_size.Y / 2)
	end

	tracer.From = camera_screen_position
	tracer.To = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
	tracer.Color = Color
	tracer.Visible = true
end

function ObjectESP:DrawName(Object: BasePart, ScreenPosition: Vector2, Size: Vector2, Distance: number, Color: Color3)
	if not self.Name then
		if self._names[Object] then
			self._names[Object].Visible = false
		end
		
		return
	end

	self._names[Object] = self._names[Object] or self:CreateDrawing("Text", {
		Text = Object.Name,
		Color = Color,
		Font = 2,
		Size = 14,
		Center = true,
		Outline = true
	})
	
	local display = Object:GetAttribute("ESPName") or Object.Name
	
	local name = self._names[Object]
	name.Text = display .. " [" .. Distance .. "m]"
	name.Position = ScreenPosition + Vector2.new(0, -Size.Y / 2 - 5)
	name.Color = Color
	name.Visible = true
end

function ObjectESP:GetBox(Object: BasePart)
	local object_cframe = Object.CFrame
	local object_size = Object.Size

	local offsets = {-0.5, 0.5}
	local corners = {}

	for _, x in next, offsets do
		for _, y in next, offsets do
			for _, z in next, offsets do
				table.insert(
					corners,
					object_cframe * Vector3.new(
						object_size.X * x,
						object_size.Y * y,
						object_size.Z * z
					)
				)
			end
		end
	end

	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = -math.huge, -math.huge

	for _, corner in next, corners do
		local screen_position, on_screen = Camera:WorldToViewportPoint(corner)
		if on_screen then
			min_x = math.min(min_x, screen_position.X)
			min_y = math.min(min_y, screen_position.Y)
			max_x = math.max(max_x, screen_position.X)
			max_y = math.max(max_y, screen_position.Y)
		end
	end

	if min_x == math.huge then
		return Vector2.new(0, 0), Vector2.new(0, 0)
	end

	local size = Vector2.new(max_x - min_x, max_y - min_y)
	local center = Vector2.new((min_x + max_x) / 2, (min_y + max_y) / 2)

	return size, center
end

function ObjectESP:Render()
	self._connections = self._connections or {}
	
	if self._render_connection then return end

	self._render_connection = RunService.RenderStepped:Connect(function()
		if not self.Enabled then return end
		if not self._tracked_objects then return end

		local root =
			LocalPlayer.Character
			and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

		for i = #self._tracked_objects, 1, -1 do
			local object = self._tracked_objects[i]

			if not object or not object.Parent then
				if object then
					self:Cleanup(object)
				end
				
				table.remove(self._tracked_objects, i)
				
				continue
			end

			local color = self.__object_colors and self.__object_colors[object] or self.DefaultColor
			if self.Rainbow then
				color = self:GetRainbow()
			end

			local size, screen_position = self:GetBox(object)

			local distance = 0
			if root then
				distance = math.floor(
					(root.Position - object.Position).Magnitude
				)
			end

			if self.MaxDistance > 0 and distance > self.MaxDistance then
				self:Cleanup(object)
				table.remove(self._tracked_objects, i)
				continue
			end

			if size.X > 0 and size.Y > 0 then
				self:DrawBox(object, screen_position, size, color)
				self:DrawTracer(object, screen_position, color)
				self:DrawName(object, screen_position, size, distance, color)
			else
				self:Cleanup(object)
			end
		end
	end)

	table.insert(self._connections, self._render_connection)
end

function ObjectESP:SetColor(Objects: BasePart | {BasePart}, Color: Color3)
	self._object_colors = self._object_colors or {}

	if typeof(Objects) ~= "table" then
		Objects = { Objects }
	end

	for _, object in next, Objects do
		if typeof(object) == "Instance" and object:IsA("BasePart") then
			self._object_colors[object] = Color
		end
	end
end

function ObjectESP:Setup(Objects: BasePart | {BasePart})
	self._tracked_objects = self._tracked_objects or {}

	if typeof(Objects) ~= "table" then
		Objects = { Objects }
	end

	for _, object in next, Objects do
		if typeof(object) == "Instance" and object:IsA("BasePart") then
			if not table.find(self._tracked_objects, object) then
				table.insert(self._tracked_objects, object)
			end
		end
	end
end

function ObjectESP:Destroy(Objects: BasePart | {BasePart})
	self._tracked_objects = self._tracked_objects or {}
	
	if not Objects then
		for _, object in next, self._tracked_objects do
			self:Cleanup(object)
		end
		
		self._tracked_objects = {}
		
		return
	end
	
	if typeof(Objects) ~= "table" then
		Objects = { Objects }
	end

	for _, object in next, Objects do
		if typeof(object) == "Instance" and object:IsA("BasePart") then
			local index = table.find(self._tracked_objects, object)
			if index then
				table.remove(self._tracked_objects, index)
			end
			
			self:Cleanup(object)
		end
	end
end

function ObjectESP:Add(Objects: BasePart | {BasePart})
	if not Objects then return end

	if typeof(Objects) == "Instance" and Objects:IsA("BasePart") then
		self:Setup(Objects)
	elseif typeof(Objects) == "table" then
		self:Setup(Objects)
	end
end

function ObjectESP:Enable()
	self.Enabled = true
	self._connections = self._connections or {}
	
	if #self._connections == 0 then
		self:Render()
	end
end

function ObjectESP:Disable()
	self.Enabled = false
	
	self:Remove()
	
	if self._connections then
		for _, connection in next, self._connections do
			if connection and connection.Disconnect then
				connection:Disconnect()
			end
		end
		
		self._connections = nil
	end
end

return ObjectESP

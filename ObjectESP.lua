local player_service = game:GetService("Players")
local run_service = game:GetService("RunService")

local player = player_service.LocalPlayer

local camera = workspace.CurrentCamera

local object_esp = {}
object_esp.__index = object_esp
object_esp.version = "1.0.2"

function object_esp.new(config)
	local self = setmetatable({}, object_esp)
	self.enabled = false
	self.box = config and config.box or false
	self.tracer = config and config.tracer or false
	self.name = config and config.name or false
	self.rainbow = config and config.rainbow or false
	self.tracer_origin = config and config.tracer_origin or "Character"
	self.default_color = config and config.default_color or Color3.fromRGB(255, 255, 255)
	self.max_distance = config and config.max_distance or 300
	self._boxes = {}
	self._tracers = {}
	self._names = {}
	self.object_colors = {}
	self._tracked_objects = {}
	self._connections = {}
	return self
end

function object_esp:_create_drawing(type, properties)
	local drawing = Drawing.new(type)
	for property, value in next, properties do
		drawing[property] = value
	end
	return drawing
end

function object_esp:_get_rainbow()
	local stored = tick()
	local hue = (math.sin(stored * 0.3) * 0.5 + 0.5)
	local saturation = 0.4 + 0.1 * math.sin(stored * 0.2 + 1)
	local value = 0.85 + 0.1 * math.sin(stored * 0.25 + 2)
	return Color3.fromHSV(hue, saturation, value)
end

function object_esp:_cleanup(object)
	local tables = {self._boxes, self._tracers, self._names}
	for _, drawing_table in next, tables do
		local drawing_object = drawing_table[object]
		if drawing_object then
			drawing_object:Remove()
			drawing_table[object] = nil
		end
	end
end

function object_esp:_remove_esp()
	for _, tbl in next, {self._tracers, self._boxes, self._names} do
		for _, obj in next, tbl do
			if obj then
				obj:Remove()
			end
		end
	end
	self._tracers, self._boxes, self._names = {}, {}, {}
end

function object_esp:_draw_box(object, screen_position, size, color)
	if not self.box then
		if self._boxes[object] then self._boxes[object].Visible = false end
		return
	end
	self._boxes[object] = self._boxes[object] or self:_create_drawing("Square", {
		Color = color,
		Thickness = 1.5,
		Transparency = 1,
		Filled = false
	})
	self._boxes[object].Size = size
	self._boxes[object].Position = Vector2.new(screen_position.X - size.X / 2, screen_position.Y - size.Y / 2)
	self._boxes[object].Color = color
	self._boxes[object].Visible = true
end

function object_esp:_draw_tracer(object, screen_position, color)
	if not self.tracer then
		if self._tracers[object] then
			self._tracers[object].Visible = false
		end
		return
	end
	self._tracers[object] = self._tracers[object] or self:_create_drawing("Line", {
		Color = color,
		Thickness = 1.5
	})
	local viewport_size = camera.ViewportSize
	local camera_screen_position
	if self.tracer_origin == "Character" then
		camera_screen_position = Vector2.new(
			viewport_size.X / 2,
			viewport_size.Y / 2
		)
	elseif self.tracer_origin == "Top" then
		camera_screen_position = Vector2.new(
			viewport_size.X / 2,
			0
		)
	elseif self.tracer_origin == "Bottom" then
		camera_screen_position = Vector2.new(
			viewport_size.X / 2,
			viewport_size.Y
		)
	else
		camera_screen_position = Vector2.new(
			viewport_size.X / 2,
			viewport_size.Y / 2
		)
	end
	self._tracers[object].From = camera_screen_position
	self._tracers[object].To = Vector2.new(screen_position.X, screen_position.Y)
	self._tracers[object].Color = color
	self._tracers[object].Visible = true
end

function object_esp:_draw_name(object, screen_position, size, distance, color)
	if not self.name then
		if self._names[object] then self._names[object].Visible = false end
		return
	end
	self._names[object] = self._names[object] or self:_create_drawing("Text", {
		Text = object.Name,
		Color = color,
		Font = 2,
		Size = 14,
		Center = true,
		Outline = true
	})
	self._names[object].Text = object.Name .. " [" .. distance .. "m]"
	self._names[object].Position = screen_position + Vector2.new(0, -size.Y/2 - 5)
	self._names[object].Color = color
	self._names[object].Visible = true
end

function object_esp:_get_screen_box(object)
	local object_cframe = object.CFrame
	local object_size = object.Size
	local offsets = {-0.5, 0.5}
	local corners = {}
	for _, x_multiplier in next, offsets do
		for _, y_multiplier in next, offsets do
			for _, z_multiplier in next, offsets do
				table.insert(corners, object_cframe * Vector3.new(object_size.X * x_multiplier, object_size.Y * y_multiplier, object_size.Z * z_multiplier))
			end
		end
	end
	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = -math.huge, -math.huge
	for _, corner in next, corners do
		local screen_position, on_screen = camera:WorldToViewportPoint(corner)
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
	return Vector2.new(max_x - min_x, max_y - min_y), Vector2.new((min_x + max_x)/2, (min_y + max_y)/2)
end

function object_esp:_render_esp()
	self._connections = self._connections or {}
	local connection = run_service.RenderStepped:Connect(function()
		if not self.enabled then return end
		if not self._tracked_objects then return end
		local humanoid_root_part = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for i = #self._tracked_objects, 1, -1 do
			local object = self._tracked_objects[i]
			if not object or not object.Parent then
				self:_cleanup(object)
				table.remove(self._tracked_objects, i)
				continue
			end
			local color = self.object_colors[object] or self.default_color
			if self.rainbow then
				color = self:_get_rainbow()
			end
			local size, screen_position = self:_get_screen_box(object)
			local distance = 0
			if humanoid_root_part then
				distance = math.floor((humanoid_root_part.Position - object.Position).Magnitude)
			end
			if self.max_distance > 0 and distance > self.max_distance then
				self:_cleanup(object)
				continue
			end
			if size.X > 0 and size.Y > 0 then
				self:_draw_box(object, screen_position, size, color)
				self:_draw_tracer(object, screen_position, color)
				self:_draw_name(object, screen_position, size, distance, color)
			else
				self:_cleanup(object)
			end
		end
	end)
	table.insert(self._connections, connection)
end

function object_esp:set_color(objects, color)
	if typeof(objects) ~= "table" then
		objects = {objects}
	end
	for _, object in next, objects do
		self.object_colors[object] = color
	end
end

function object_esp:setup(objects)
	if typeof(objects) ~= "table" then
		objects = {objects}
	end
	for _, object in next, objects do
		if not table.find(self._tracked_objects, object) then
			table.insert(self._tracked_objects, object)
		end
	end
end

function object_esp:Destroy(target)
	if not target then
		for _, t in next, self._tracked_objects do
			self:_cleanup(t)
		end
		self._tracked_objects = {}
		return
	end
	if typeof(target) == "Instance" then
		local index = table.find(self._tracked_objects, target)
		if index then
			table.remove(self._tracked_objects, index)
		end
		self:_cleanup(target)
		return
	end
	if type(target) == "table" then
		for _, object_instance in next, target do
			if typeof(object_instance) == "Instance" then
				local index = table.find(self._tracked_objects, object_instance)
				if index then
					table.remove(self._tracked_objects, index)
				end
				self:_cleanup(object_instance)
			end
		end
		return
	end
end

function object_esp:Enable()
	self.enabled = true
	if not self._connections or #self._connections == 0 then
		self:_render_esp()
	end
end

function object_esp:Disable()
	self.enabled = false
	self:_remove_esp()
	if self._connections then
		for _, connection in next, self._connections do
			connection:Disconnect()
		end
		self._connections = nil
	end
end

return object_esp

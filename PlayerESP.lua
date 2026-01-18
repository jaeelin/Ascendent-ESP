local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local player_esp = {}
player_esp.__index = player_esp
player_esp.version = "1.0.5"

function player_esp.new(config)
	local self = setmetatable({}, player_esp)

	self.Enabled = false
	
	self.Box = config and config.Box or false
	self.HealthBar = config and config.HealthBar or false
	self.Tracer = config and config.Tracer or false
	self.Skeleton = config and config.Skeleton or false
	self.Name = config and config.Name or false
	self.Arrows = config and config.Arrows or false
	self.Rainbow = config and config.Rainbow or false
	self.TracerOrigin = config and config.TracerOrigin or "Character"
	self.DefaultColor = config and config.DefaultColor or Color3.fromRGB(180, 255, 180)
	self.MaxDistance = config and config.MaxDistance or 300

	self._boxes = {}
	self._health_bars = {}
	self._tracers = {}
	self._skeletons = {}
	self._names = {}
	self._arrows = {}
	self.target_colors = {}
	self._active_targets = {}
	self._connections = {}

	return self
end

function player_esp:_create_drawing(type, properties)
	local drawing = Drawing.new(type)
	for property, value in next, properties do
		drawing[property] = value
	end
	return drawing
end

function player_esp:_get_rainbow()
	local stored = tick()
	local hue = (math.sin(stored * 0.3) * 0.5 + 0.5)
	local saturation = 0.4 + 0.1 * math.sin(stored * 0.2 + 1)
	local value = 0.85 + 0.1 * math.sin(stored * 0.25 + 2)
	return Color3.fromHSV(hue, saturation, value)
end

function player_esp:_draw_bone(target, index, point_a, point_b, color)
	if not point_a or not point_b then return end

	local point_a_position, a_on_screen = Camera:WorldToViewportPoint(point_a.Position)
	local point_b_position, b_on_screen = Camera:WorldToViewportPoint(point_b.Position)

	self._skeletons[target] = self._skeletons[target] or {}
	self._skeletons[target][index] = self._skeletons[target][index] or self:_create_drawing("Line", {
		Thickness = 1.5,
		Color = color,
		Transparency = 1
	})

	local line = self._skeletons[target][index]
	line.From = Vector2.new(point_a_position.X, point_a_position.Y)
	line.To = Vector2.new(point_b_position.X, point_b_position.Y)
	line.Visible = a_on_screen or b_on_screen
	line.Color = color
end

function player_esp:_cleanup(target)
	for _, esp_table in next, {self._boxes, self._health_bars, self._tracers, self._names, self._arrows} do
		local object = esp_table[target]
		if object then
			if type(object) == "table" then
				for _, obj in next, object do
					if obj then obj:Remove() end
				end
			else
				object:Remove()
			end
			esp_table[target] = nil
		end
	end

	if self._skeletons[target] then
		for _, line in next, self._skeletons[target] do
			if line then line:Remove() end
		end
		self._skeletons[target] = nil
	end
end

function player_esp:_remove_esp()
	local all_tables = {self._tracers, self._boxes, self._names, self._health_bars, self._arrows}
	for _, tbl in next, all_tables do
		for _, object in next, tbl do
			if type(object) == "table" then
				for _, sub_object in next, object do
					sub_object.Visible = false
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

	self._tracers = {}
	self._boxes = {}
	self._names = {}
	self._health_bars = {}
	self._skeletons = {}
	self._arrows = {}
end

function player_esp:_draw_box(target, screen_position, box_width, box_height, color)
	if not self.Box then
		if self._boxes[target] then
			self._boxes[target].Visible = false
		end
		return
	end

	self._boxes[target] = self._boxes[target] or self:_create_drawing("Square", {
		Color = color,
		Thickness = 1.5,
		Filled = false,
		Transparency = 1
	})

	self._boxes[target].Size = Vector2.new(box_width, box_height)
	self._boxes[target].Position = Vector2.new(screen_position.X - box_width / 2, screen_position.Y - box_height / 2)
	self._boxes[target].Color = color
	self._boxes[target].Visible = true
end

function player_esp:_draw_health_bar(target, screen_position, box_width, box_height)
	if not self.HealthBar then
		if self._health_bars and self._health_bars[target] then
			self._health_bars[target].Visible = false
		end
		return
	end

	self._health_bars[target] = self._health_bars[target] or self:_create_drawing("Square", {
		Color = Color3.fromRGB(150, 255, 150),
		Thickness = 1,
		Filled = true,
		Transparency = 1
	})

	local humanoid = target.Character and target.Character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		self._health_bars[target].Visible = false
		return
	end

	local health_percent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	local health_color
	if health_percent <= 0.5 then
		health_color = Color3.fromRGB(255, 150, 150):Lerp(Color3.fromRGB(255, 220, 150), health_percent * 2)
	else
		health_color = Color3.fromRGB(255, 220, 150):Lerp(Color3.fromRGB(150, 255, 150), (health_percent - 0.5) * 2)
	end

	local bar_x = screen_position.X + (box_width / 2) + 2
	local bar_y = screen_position.Y - box_height / 2 + (box_height * (1 - health_percent))

	self._health_bars[target].Size = Vector2.new(3, box_height * health_percent)
	self._health_bars[target].Position = Vector2.new(bar_x, bar_y)
	self._health_bars[target].Color = health_color
	self._health_bars[target].Visible = true
end

function player_esp:_draw_tracer(target, screen_position, color)
	if not self.Tracer then
		if self._tracers[target] then
			self._tracers[target].Visible = false
		end
		return
	end

	self._tracers[target] = self._tracers[target] or self:_create_drawing("Line", {
		Color = color,
		Thickness = 1.5
	})

	local viewport_size = Camera.ViewportSize
	local camera_screen_position

	if self.TracerOrigin == "Character" then
		camera_screen_position = Vector2.new(viewport_size.X / 2, viewport_size.Y / 2)
	elseif self.TracerOrigin == "Top" then
		camera_screen_position = Vector2.new(viewport_size.X / 2, 0)
	elseif self.TracerOrigin == "Bottom" then
		camera_screen_position = Vector2.new(viewport_size.X / 2, viewport_size.Y)
	else
		camera_screen_position = Vector2.new(viewport_size.X / 2, viewport_size.Y / 2)
	end

	self._tracers[target].From = camera_screen_position
	self._tracers[target].To = Vector2.new(screen_position.X, screen_position.Y)
	self._tracers[target].Color = color
	self._tracers[target].Visible = true
end

function player_esp:_draw_name(target, screen_position, box_height, distance, color)
	if not self.Name then
		if self._names[target] then
			self._names[target].Visible = false
		end
		return
	end

	self._names[target] = self._names[target] or self:_create_drawing("Text", {
		Text = target.Name,
		Color = color,
		Font = 2,
		Size = 14,
		Center = true,
		Outline = true
	})

	self._names[target].Text = target.Name .. " [" .. distance .. "m]"
	self._names[target].Position = Vector2.new(screen_position.X, screen_position.Y - box_height / 2 - 15)
	self._names[target].Color = color
	self._names[target].Visible = true
end

function player_esp:_draw_skeleton(target, character, color)
	if not self.Skeleton then
		for _, skeleton in next, self._skeletons do
			for _, line in next, skeleton do
				line.Visible = false
			end
		end
		return
	end

	local function get_part(part)
		local object = character:FindFirstChild(part)
		if object and object:IsA("BasePart") then
			return object
		end
		return nil
	end

	local torso = get_part("Torso") or get_part("UpperTorso")
	local lower_torso = get_part("LowerTorso")
	local root = torso or lower_torso

	local parts = {
		Head = get_part("Head"),
		Torso = torso,
		LowerTorso = lower_torso,
		LeftUpperArm = get_part("Left Arm") or get_part("LeftUpperArm"),
		RightUpperArm = get_part("Right Arm") or get_part("RightUpperArm"),
		LeftLowerArm = get_part("LeftLowerArm"),
		RightLowerArm = get_part("RightLowerArm"),
		LeftUpperLeg = get_part("Left Leg") or get_part("LeftUpperLeg"),
		RightUpperLeg = get_part("Right Leg") or get_part("RightUpperLeg"),
		LeftLowerLeg = get_part("LeftLowerLeg"),
		RightLowerLeg = get_part("RightLowerLeg")
	}

	self:_draw_bone(target, 1, parts.Head, root, color)

	if parts.LeftUpperArm then
		self:_draw_bone(target, 2, root, parts.LeftUpperArm, color)
		if parts.LeftLowerArm then self:_draw_bone(target, 3, parts.LeftUpperArm, parts.LeftLowerArm, color) end
	end

	if parts.RightUpperArm then
		self:_draw_bone(target, 4, root, parts.RightUpperArm, color)
		if parts.RightLowerArm then self:_draw_bone(target, 5, parts.RightUpperArm, parts.RightLowerArm, color) end
	end

	if parts.LeftUpperLeg then
		self:_draw_bone(target, 6, root, parts.LeftUpperLeg, color)
		if parts.LeftLowerLeg then self:_draw_bone(target, 7, parts.LeftUpperLeg, parts.LeftLowerLeg, color) end
	end

	if parts.RightUpperLeg then
		self:_draw_bone(target, 8, root, parts.RightUpperLeg, color)
		if parts.RightLowerLeg then self:_draw_bone(target, 9, parts.RightUpperLeg, parts.RightLowerLeg, color) end
	end

	for _, line in next, self._skeletons[target] or {} do
		line.Color = color
	end
end

function player_esp:_draw_arrows(target, _, color)
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

	local viewport_size = Camera.ViewportSize
	local screen_center = Vector2.new(viewport_size.X / 2, viewport_size.Y / 2)

	local target_position = character.HumanoidRootPart.Position
	local camera_position = Camera.CFrame.Position
	local to_target = (target_position - camera_position)

	local right = Camera.CFrame.RightVector
	local up = Camera.CFrame.UpVector

	local x_dir = to_target:Dot(right)
	local y_dir = -to_target:Dot(up)
	local direction = Vector2.new(x_dir, y_dir)

	if direction.Magnitude > 0 then
		direction = direction.Unit
	end

	local arrow_distance = 50
	local arrow_position = screen_center + direction * arrow_distance
	local arrow_size = 10

	local angle = math.atan2(direction.Y, direction.X)

	local point1 = arrow_position + Vector2.new(math.cos(angle) * arrow_size, math.sin(angle) * arrow_size)
	local point2 = arrow_position + Vector2.new(math.cos(angle + 2.5) * arrow_size, math.sin(angle + 2.5) * arrow_size)
	local point3 = arrow_position + Vector2.new(math.cos(angle - 2.5) * arrow_size, math.sin(angle - 2.5) * arrow_size)

	for i, point in next, {point1, point2, point3} do
		self._arrows[target][i] = self._arrows[target][i] or self:_create_drawing("Line", {
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

function player_esp:_update_target_esp(target)
	local character = target.Character
	if not character or not character.Parent then
		self:_cleanup(target)
		return
	end

	local humanoid_root_part = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")

	if not humanoid_root_part or not humanoid or humanoid.Health <= 0 then
		self:_cleanup(target)
		return
	end

	local color = self.target_colors[target] or self.DefaultColor
	if self.Rainbow then
		color = self:_get_rainbow()
	end

	local head_position, head_on_screen = Camera:WorldToViewportPoint(
		humanoid_root_part.Position + Vector3.new(0, 3, 0)
	)
	local foot_position, foot_on_screen = Camera:WorldToViewportPoint(
		humanoid_root_part.Position - Vector3.new(0, 3, 0)
	)

	local box_height = foot_position.Y - head_position.Y
	local box_width = box_height / 1.5

	local box_center = Vector2.new(
		(head_position.X + foot_position.X) / 2,
		(head_position.Y + foot_position.Y) / 2
	)

	local distance = 0
	local local_root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if local_root then
		distance = math.floor((local_root.Position - humanoid_root_part.Position).Magnitude)
	end

	if self.MaxDistance > 0 and distance > self.MaxDistance then
		self:_cleanup(target)
		return
	end

	if not (head_on_screen or foot_on_screen) then
		self:_cleanup(target)
		self:_draw_arrows(target, box_center, color)
		return
	else
		if self._arrows[target] then
			for _, line in next, self._arrows[target] do
				line.Visible = false
			end
		end
	end

	self:_draw_box(target, box_center, box_width, box_height, color)
	self:_draw_health_bar(target, box_center, box_width, box_height)
	self:_draw_tracer(target, box_center, color)
	self:_draw_name(target, box_center, box_height, distance, color)
	self:_draw_skeleton(target, character, color)
end

function player_esp:setup_esp(target)
	if target == LocalPlayer then return end
	self._active_targets[target] = true

	if not self._render_connection then
		self._render_connection = RunService.RenderStepped:Connect(function()
			if not self.Enabled then return end
			for active_target in next, self._active_targets do
				self:_update_target_esp(active_target)
			end
		end)
		table.insert(self._connections, self._render_connection)
	end
end

function player_esp:SetColor(target_player, color)
	self.target_colors[target_player] = color
end

function player_esp:Destroy(target)
	if not target then
		for t in next, self._active_targets do
			self:_cleanup(t)
		end

		self._active_targets = {}

		return
	end

	if typeof(target) == "Instance" and target:IsA("Player") then
		self._active_targets[target] = nil
		self:_cleanup(target)
		return
	end

	if type(target) == "table" then
		for _, player_instance in next, target do
			if typeof(player_instance) == "Instance" and player_instance:IsA("Player") then
				self._active_targets[player_instance] = nil
				self:_cleanup(player_instance)
			end
		end

		return
	end
end

function player_esp:Add(target)
	if not target then return end
	
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end
	
	if not self._active_targets[target] then
		self:setup_esp(target)
	end
end

function player_esp:Enable()
	self.Enabled = true

	for _, target in next, Players:GetPlayers() do
		self:setup_esp(target)
	end

	table.insert(self._connections, Players.PlayerAdded:Connect(function(target)
		self:setup_esp(target)
	end))

	table.insert(self._connections, Players.PlayerRemoving:Connect(function(target)
		self._active_targets[target] = nil
		self:_cleanup(target)
	end))
end

function player_esp:Disable()
	self.Enabled = false

	if self._active_targets then
		for target in next, self._active_targets do
			self:_cleanup(target)
		end
	end

	self:_remove_esp()

	for _, connection in next, self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return player_esp

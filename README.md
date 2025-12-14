<h1 align="center">Ascendent ESP</h1>

<div align="center">
<strong>⚠️ This library only supports executors that have Drawing Lib! ⚠️</strong>
</div>

<h2 align="center">Player ESP</h2>

## Features
- Box ESP

- Health Bar ESP

- Tracers

- Name ESP

- Skeleton ESP

- Rainbow ESP

- Custom player colors

<h2 align="center">Setup</h2>

To get started, load the library.
```lua
local AscendentESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/PlayerESP.lua"))()

local NewESP = AscendentESP.new()
```
Then, setup your configurations.

```lua
NewESP.boxEnabled = true
NewESP.healthBarEnabled = true
NewESP.tracerEnabled = true
NewESP.skeletonEnabled = true
NewESP.nameEnabled = false
NewESP.rainbowEnabled = false

NewESP.defaultColor = Color3.fromRGB(250, 150, 255)
```

Lastly, enable your ESP.

```lua
NewESP:Enable()
```

<h2 align="center">Example Code</h2>

```lua
local AscendentESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/PlayerESP.lua"))()

local NewESP = AscendentESP.new()

NewESP.boxEnabled = true
NewESP.healthBarEnabled = true
NewESP.tracerEnabled = true
NewESP.skeletonEnabled = true
NewESP.nameEnabled = true

NewESP:Enable()
```
<p align="center">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/PlayerESP/Box.png" alt="Box ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/PlayerESP/Tracer.png" alt="Tracer ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/PlayerESP/All.png" alt="Combined ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/PlayerESP/Skeleton.png" alt="Skeleton ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/PlayerESP/Name.png" alt="Name ESP" width="150" style="vertical-align: middle;">
</p>

<h2 align="center">Methods</h2>

```lua
<Object>:Enable()
```
- Enables the ESP to fully display.

```lua
<Object>:Disable()
```
- Disables the ESP completely and destroys any drawing objects.

```lua
<Object>:SetColor(<Player>, <Color3>)
```
- Sets a color for a specific player.

<h2 align="center">Object ESP</h2>

## Features
- Box ESP

- Tracers

- Name ESP

- Rainbow ESP

- Custom object colors

<h2 align="center">Setup</h2>

To get started, load the library.
```lua
local AscendentESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/ObjectESP.lua"))()

local NewESP = AscendentESP.new()
```
Then, setup your configurations.

```lua
NewESP.boxEnabled = true
NewESP.tracerEnabled = true
NewESP.nameEnabled = false
NewESP.rainbowEnabled = false

NewESP.defaultColor = Color3.fromRGB(250, 150, 255)
```

Then, setup your objects using :Setup().

Note: You can use a singular object or a table of objects.

```lua
local objects = {}

for _, object in next, workspace:GetChildren() do
	if object.Name == "Part" then
		table.insert(objects, object)
	end
end

NewESP:Setup(objects)
```

Lastly, enable the ESP.

```lua
NewESP:Enable()
```

<h2 align="center">Example Code</h2>

```lua
local AscendentESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/ObjectESP.lua"))()

local NewESP = AscendentESP.new()

NewESP.boxEnabled = true
NewESP.tracerEnabled = true
NewESP.nameEnabled = false
NewESP.rainbowEnabled = false

NewESP.defaultColor = Color3.fromRGB(250, 150, 255)

local objects = {}

for _, object in next, workspace:GetChildren() do
	if object.Name == "Part" then
		table.insert(objects, object)
	end
end

NewESP:Setup(objects)

NewESP:Enable()
```
<p align="center">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/Images/ObjectESP/ObjectBox.png" alt="Box ESP" width="320" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/Images/ObjectESP/ObjectTracer.png" alt="Tracer ESP" width="320" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/Images/ObjectESP/ObjectName.png" alt="Name ESP" width="320" style="vertical-align: middle;">
</p>

<h2 align="center">Methods</h2>

```lua
<Object>:Enable()
```
- Enables the ESP to fully display.

```lua
<Object>:Disable()
```
- Disables the ESP completely and destroys any drawing objects.

```lua
<Object>:SetColor(<Instance> or {<Instance>, <Instance>, ...}, <Color3>)
```
- Sets a color for a specific part or multiple parts.

```lua
<Object>:Setup(<Instance> or {<Instance>, <Instance>, ...})
```
- Sets up ESP for one or multiple parts.

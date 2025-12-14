<h1 align="center">Ascendent Hub</h1>

<div align="center">
<strong>⚠️ This library only supports executors that have Drawing Lib! ⚠️</strong>
</div>

## Features
• Box ESP

• Tracers

• Name ESP

• Skeleton ESP

• Rainbow ESP

• Custom player colors

<h2 align="center">Setup</h2>

To get started, load the library.
```lua
local AscendentESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/Main.lua"))()

local NewESP = AscendentESP.new()
```
Then, setup your configurations.

```lua
NewESP.boxEnabled = true
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
local AscendentESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/refs/heads/main/Main.lua"))()

local NewESP = AscendentESP.new()

NewESP.boxEnabled = true
NewESP.tracerEnabled = true
NewESP.skeletonEnabled = true
NewESP.nameEnabled = true

NewESP:Enable()
```
<p align="center">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/Box.png" alt="Box ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/Tracer.png" alt="Tracer ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/All.png" alt="Combined ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/Skeleton.png" alt="Skeleton ESP" width="150" style="vertical-align: middle;">
  <img src="https://raw.githubusercontent.com/jaeelin/Ascendent-ESP/main/Images/Name.png" alt="Name ESP" width="150" style="vertical-align: middle;">
</p>

<h2 align="center">Methods</h2>

```lua
<Object> :Enable()
```
- Enables the ESP to fully display.

```lua
<Object> :Disable()
```
- Disables the ESP completely and destroys any drawing objects.

```lua
<Object> :SetColor(<Player>, <Color3>)
```
- Sets a color for a specific player.

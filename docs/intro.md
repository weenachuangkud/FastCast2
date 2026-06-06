---
sidebar_position: 1
---

<div style={{ textAlign: "center", marginBottom: 32 }}>
  <img
    src="https://github.com/user-attachments/assets/b4697a13-5701-491b-8e8e-7c12696baceb"
    alt="FastCast2 Cover"
    style={{
      width: "100%",
      maxHeight: "360px",
      objectFit: "contain"
    }}
  />
</div>

![Roblox](https://img.shields.io/badge/made%20for-Roblox-blue?style=for-the-badge&logo=roblox)
![Luau](https://img.shields.io/badge/language-Luau-blueviolet?style=for-the-badge)
![GitHub release](https://img.shields.io/github/v/release/weenachuangkud/FastCast2?style=for-the-badge)
[![DevForum](https://img.shields.io/badge/discuss-DevForum-orange?style=for-the-badge&logo=roblox)](https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed/4093890)

# FastCast2

> Unofficial continuation of FastCast for Roblox

**An improved version of [FastCast](https://etithespir.it/FastCastAPIDocs/)** with **Parallel scripting**, **more extensions**, and **statically typed**. <br /> **A powerful modern projectile** library

**FastCast2** It's a **Roblox projectile library** powered by [VMsDispatcher](https://github.com/weenachuangkud/VMsDispatcher) designed to simulate **thousands** of projectiles without relying on physics replication.

Because FastCast is no longer actively maintained by [EtiTheSpirit](https://github.com/EtiTheSpirit), this repository continues the project with updates and adaptations.

<br />

# Benefits of using FastCast2

- Highly customizable
- Versatile projectile library
- Parallel scripting support
- Easy to use and integrate
- Raycast and Blockcast, Spherecast support
- BulkMoveTo/Motor6D support
- Built-in castVisualization
- Built-in ObjectCache
- Built-in HighFidelitySegment control
- Flexible and extensible design
- Improves development productivity
- High Performance
- Completely free

FastCast2 is an open-source project, and contributions from the community are welcome. <br />
Read more on [FastCast2 devforum](https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed/4093890)

---
# Installation guide


1. Go to [Releases](https://github.com/weenachuangkud/FastCast2/releases) and install the `.rbxm` file from the latest release.
2. Open Roblox Studio and open any project.
3. Go to **File → Import Roblox Model** and import the `.rbxm` file.
4. After importing, **FastCast2** will appear in your Workspace.
5. Drag **FastCast2** into **ReplicatedStorage**.
6. Create a Part and set:
   - Size to `1, 1, 1`
   - `CanTouch` = false  
   - `CanCollide` = false  
   - `CanQuery` = false  
7. Done — you’re ready to use FastCast2.

---

## Install with Rojo

1. Install the [Rojo CLI](https://rojo.space/docs/installation/) for your system.
2. Clone this repository:
   ```bash
   git clone https://github.com/weenachuangkud/FastCast2.git
   cd FastCast2
   rm -rf .git
   ```
3. Sync to Roblox:
   ```bash
   rojo sync -o <place-name>
   ```
   Or serve live with:
   ```bash
   rojo serve
   ```
   Then connect in Roblox Studio via **Studio → Plugins → Rojo**.

---

# Code example

Shooting projectiles from your head (Serial mode - simpler, main thread):

```lua
-- Services
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Requires
local FastCast2 = require(Rep:WaitForChild("FastCast2"))
local FastCastEnums = require(Rep:WaitForChild("FastCast2"):WaitForChild("FastCastEnums"))

-- CONSTANTS
local SPEED = 500

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local Head = character:WaitForChild("Head")
local Mouse = player:GetMouse()

local ProjectileContainer = workspace:WaitForChild("Projectiles")
local ProjectileTemplate = Rep:WaitForChild("Projectile")

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- Behavior (FastCastBehavior)
local behavior = FastCast2.newBehavior()
behavior.MaxDistance = 1000
behavior.RaycastParams = CastParams
behavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
behavior.HighFidelitySegmentSize = 1
behavior.Acceleration = Vector3.new(0, -workspace.Gravity/2.3, 0)
behavior.CosmeticBulletContainer = ProjectileContainer
behavior.CosmeticBulletTemplate = ProjectileTemplate


-- Serial Caster (runs on main thread, simpler)
local Caster = FastCast2.new()
Caster:Init("BulkMoveTo", false) -- movementMode, useObjectCache

-- Events (can be set before Init)
Caster.Hit = function(cast, result, velocity, bullet)
	print("Hit: " .. result.Instance.Name)
end

-- Fire
local function fire()
	local origin = Head.Position
	local direction = (Mouse.Hit.Position - origin).Unit
	Caster:RaycastFire(origin, direction, SPEED, behavior)
end

-- Input
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fire()
	end
end)
```

### Blockcast & Spherecast

Swap `RaycastFire` for `BlockcastFire` or `SpherecastFire` to change cast type:

```lua
-- Blockcast: pass a Vector3 size after origin
Caster:BlockcastFire(origin, Vector3.new(2, 4, 2), direction, SPEED, behavior)

-- Spherecast: pass a number radius after origin
Caster:SpherecastFire(origin, 3, direction, SPEED, behavior)
```

### ObjectCache (bullet pooling)

ObjectCache reuses cosmetic bullet instances instead of creating/destroying them every shot:

```lua
local Caster = FastCast2.new()
Caster:Init("BulkMoveTo", true, ProjectileTemplate, 500, workspace)
--                                    ^template   ^size  ^holder
```

The cache pre-allocates 500 parts by default, auto-expands when exhausted, and moves retired
parts to a far-away CFrame via `BulkMoveTo` — no instance creation/destruction overhead.

### Parallel mode (high-performance with multiple VMs)

```lua
local Caster = FastCast2.newParallel()
Caster:Init(
	4,                 -- numWorkers
	workspace,         -- VM folder parent
	"FastCastVMs",     -- VM folder name
	workspace,         -- container parent
	"VMContainer",     -- container name
	"VM",              -- VM name
	"BulkMoveTo",      -- movementMode
	nil,               -- FastCastEventsModule (optional)
	false              -- useObjectCache
)

-- Events work the same as serial
Caster.Hit = function(cast, result, velocity, bullet)
	print("Hit: " .. result.Instance.Name)
end

--[[
	-- Except:
	-- Caster.CanPierce
	--> You will have to use FastCastEventsModule for that
]]

-- Fire the same as serial
Caster:RaycastFire(origin, direction, SPEED, behavior)
Caster:BlockcastFire(origin, Vector3.new(2, 4, 2), direction, SPEED, behavior)
Caster:SpherecastFire(origin, 3, direction, SPEED, behavior)
```

<br />

How to set up [FastCastEventsModule](https://weenachuangkud.github.io/FastCast2/api/TypeDefinitions/#FastCastEventsModule)

```lua
-- Services
local Rep = game:GetService("ReplicatedStorage")

-- Modules

local FastCast2 = Rep:WaitForChild("FastCast2")

-- Requires
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))

-- Module

local module: TypeDef.FastCastEvents = {}

local debounce = false
local debounce_time = 0.2

module.LengthChanged = function(cast : TypeDef.ActiveCastData)
	if not debounce then
		debounce = true
		print("OnLengthChanged Test")
		task.delay(debounce_time, function()
			debounce = false
		end)
	end
end

module.CastFire = function()
	print("CastFire!")
end

module.CastTerminating = function()
	print("CastTerminating!")
end

module.Hit = function()
	print("Hit!")
end

module.CanPierce = function(cast : TypeDef.ActiveCastData, resultOfCast : RaycastResult, segmentVelocity, CosmeticBulletObject)
	local CanPierce = false
	if resultOfCast.Instance:GetAttribute("CanPierce") == true then
		CanPierce = true
	end
	print(CanPierce)
	return CanPierce
end

module.Pierced = function()
	print("Pierced!")
end


return module
```

Register it on your parallel caster after `Init`:

```lua
Caster:SetFastCastEventsModule(pathTo.FastCastEventsModule)
```

> **Note**: `SetFastCastEventsModule` is only available on parallel casters. In serial mode, set event handlers directly on the caster (e.g., `Caster.Hit = function(...)`).

### Motor6D movement mode

Motor6D mode uses `Motor6D.Transform` for more performance instead of `BulkMoveTo`:

```lua
local Caster = FastCast2.new()
Caster:Init("Motor6D", false) -- movementMode = "Motor6D"
```

All active casts automatically get a Motor6D connection on registration and disconnection on cleanup.
You can switch modes at runtime:

```lua
Caster:SetMovementModeEnabled(true, "Motor6D")   -- enable Motor6D
Caster:SetMovementModeEnabled(true, "BulkMoveTo") -- switch back
```

### Cast manipulation

Modify active casts at runtime using the static `FastCast` methods:

```lua
-- Read state
local pos = FastCast2.GetPositionCast(cast)
local vel = FastCast2.GetVelocityCast(cast)
local accel = FastCast2.GetAccelerationCast(cast)

-- Modify state (automatically rebases trajectory)
FastCast2.SetPositionCast(cast, Vector3.new(0, 50, 0))
FastCast2.SetVelocityCast(cast, Vector3.new(0, 100, 0))
FastCast2.SetAccelerationCast(cast, Vector3.new(0, -workspace.Gravity, 0))

-- Relative changes
FastCast2.AddPositionCast(cast, Vector3.new(0, 10, 0))
FastCast2.AddVelocityCast(cast, Vector3.new(0, 20, 0))
FastCast2.AddAccelerationCast(cast, Vector3.new(0, -50, 0))

-- Terminate a cast early (fires CastTerminating and cleans up)
FastCast2.TerminateCast(cast)
```

> **Tip**: In parallel mode, call `Caster:SyncChangesToCast(cast)` after modifying to push changes into the worker VM.

### -> Get started with the [FastCast2 documentation](https://weenachuangkud.github.io/FastCast2/docs/api-reference)

---

# People behind FastCast2(Contributors)
- [CK06](https://github.com/weenachuangkud): Main developer, Maintainer, Graphic designer
- [Naymmmm](https://github.com/Naymmmm): Help with proper docs, CI, Rojo supports, wally supports, Github pages(Moonwave)
- [EtiTheSpirit](https://github.com/EtiTheSpirit): Original developer
- [Per2iako](https://github.com/Per2iako): Fix ActivesRef was overwritten (BaseParallel, ParallelSimulation)

# Special Thanks

Special thanks to the following people from the Suphi Kaner Discord Server:

- @avibah — For helping me create VMDispatcher
- @ace9b472eeec4f53ba9e8d91bo87c636 — For advice, feedback, and ideas
- @23sinek345 — For code reviews, benchmark discussions, and improvement suggestions

And thanks to everyone else in the server who helped along the way.

More broadly, community feedback has played a significant role in FastCast2's existence and development. Many ideas, discussions, and sources of motivation came from conversations within the Suphi Kaner Discord server. FastCast2 would not be where it is today without the contributions, feedback, and support of the community.

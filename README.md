
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
- BulkMoveTo support
- Built-in ObjectCache
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

# Code example

Shooting projectiles from your head (Serial mode - simpler, main thread):

```lua
-- Services
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Requires
local FastCast2 = require(Rep:WaitForChild("FastCast2"))

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

-- MovementMethod: "BulkMoveTo" (default) or "Transform" (Motor6D)
behavior.MovementMethod = "BulkMoveTo"

-- Serial Caster (runs on main thread, simpler)
local Caster = FastCast2.new()
Caster:Init(true, false) -- useBulkMoveTo, useObjectCache

-- Events
Caster.CastTerminating:Connect(function(cast)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then obj:Destroy() end
end)

Caster.Hit:Connect(function(cast, result, velocity, bullet)
	print("Hit: " .. result.Instance.Name)
end)

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

Parallel mode (for high-performance with multiple VMs):

```lua
-- Parallel Caster (requires Init with worker count)
local Caster = FastCast2.newParallel()
Caster:Init(
	4,              -- numWorkers (thread count)
	workspace,      -- newParent (VM folder parent)
	"FastCastVMs",  -- VM folder name
	workspace,      -- ContainerParent
	"VMContainer", -- Container name
	"VM",           -- VM name
	true,           -- useBulkMoveTo
	nil,            -- FastCastEventsModule
	false           -- useObjectCache
)

-- Fire same as serial
Caster:RaycastFire(origin, direction, speed, behavior)
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

module.RayHit = function()
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

After this, add this piece of code below the `FastCast:Init(...)`:

```lua
	Caster:SetFastCastEventsModule(pathTo.FastCastEventsModule)
```

(FastCastEventsModule can be used to optimize some FastCastEvents, like LengthChanged)

### -> Get started with the [FastCast2 documentation](https://weenachuangkud.github.io/FastCast2/)

---

# People behind FastCast2
- [Mawin CK](https://github.com/weenachuangkud): Main developer, Maintainer, Graphic designer
- [Naymmmm](https://github.com/Naymmmm): Help with proper docs, CI, Rojo supports, wally supports, Github pages(Moonwave)
- [EtiTheSpirit](https://github.com/EtiTheSpirit): Original developer

<br />

# Special Thanks

Thanks to the following people from the **Suphi Kaner Discord Server**:


- **@avibah** — For helping me create **VMDispatcher**
- **@ace9b472eeec4f53ba9e8d91bo87c636** — For advice and ideas
- **@23sinek345** — For code review and improvement suggestions


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
- Parallel scripting support
- Easy to use and integrate
- Raycast and Blockcast support
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
Shooting projectiles from your head
```lua
-- Services
local Rep = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")

-- Requires
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local FastCastEnums = require(FastCast2:WaitForChild("FastCastEnums"))
local FastCastM = require(FastCast2)

-- CONSTANTS
local SPEED = 500

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local Head = character:WaitForChild("Head")

local Mouse = player:GetMouse()

local ProjectileContainer = workspace:WaitForChild("Projectiles")
local ProjectileTemplate = Rep:WaitForChild("Projectile")

local debounce = false
local debounce_time = 0.05

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- Behavior
local castBehavior: FastCastTypes = FastCastM.newBehavior()
castBehavior.MaxDistance = 1000 -- Explictly set MaxDistance to 1000
castBehavior.RaycastParams = CastParams
castBehavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
castBehavior.HighFidelitySegmentSize = 1
castBehavior.Acceleration = Vector3.new(0, -workspace.Gravity/2.3, 0)
castBehavior.AutoIgnoreContainer = true
castBehavior.CosmeticBulletContainer = ProjectileContainer
castBehavior.CosmeticBulletTemplate = ProjectileTemplate
castBehavior.FastCastEventsConfig = {
	UseHit = true,
	UseLengthChanged = false, -- Warning: This will make your FPS tank
	UseCastTerminating = true,
	UseCastFire = true,
	UsePierced = false
}

-- Caster
local Caster = FastCastM.new()
Caster:Init(
	4, -- Roblox limits at 4 :(
	RepFirst,
	"CastVMs",
	RepFirst,
	"CastVMContainer",
	"CastVM",
	true
)

-- Functions

local function OnCastTerminating(cast: FastCastTypes.ActiveCastCompement)
	local obj = cast.RayInfo.CosmeticBulletObject
	if obj then 
		obj:Destroy()
	end
end

local function OnHit()
	print("Hit!")
end

local function OnCastFire()
	print("CastFire!")
end

-- Connections

Caster.CastTerminating:Connect(OnCastTerminating)
Caster.Hit:Connect(OnHit)
Caster.CastFire:Connect(OnCastFire)

UIS.InputBegan:Connect(function(Input: InputObject, gp: boolean)
	if gp then return end
	if debounce then return end
	
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		debounce = true
		
		local Origin = Head.Position
		local Direction = (Mouse.Hit.Position - Origin).Unit
		
		Caster:RaycastFire(Origin, Direction, SPEED, castBehavior)
		
		task.wait(debounce_time)
		debounce = false
	end
end)
```

### Get started with the [FastCast2 documentation](https://weenachuangkud.github.io/FastCast2/)


---


# People behind FastCast2
- [Mawin CK](https://github.com/weenachuangkud): Main developer, Maintainer, Graphic designer 
- [Naymmmm](https://github.com/Naymmmm): Help with proper docs, CI, Rojo supports, wally supports, Github pages(Moonwave)
- [EtiTheSpirit](https://github.com/EtiTheSpirit): Original developer

<br />

# SPECIAL THANKS TO
- @avibah On Discord: **For helping me make VMDispatcher**
- @ace9b472eeec4f53ba9e8d91bo87c636 On Discord: **For advice/ideas**


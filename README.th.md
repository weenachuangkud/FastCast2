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

<div align="center">

การพัฒนาต่อแบบไม่เป็นทางการของ FastCast Roblox

**เวอร์ชันที่ปรับปรุงจาก [FastCast](https://etithespir.it/FastCastAPIDocs/)** ที่รองรับ **Parallel scripting**, **extension เพิ่มเติม** และ **statically typed** <br /> ไลบรารีสำหรับทำ **projectile สมัยใหม่ที่ทรงพลัง**

</div>

<div align="center">

![GitHub release](https://img.shields.io/github/v/release/weenachuangkud/FastCast2?style=for-the-badge)
[![DevForum](https://img.shields.io/badge/discuss-DevForum-orange?style=for-the-badge&logo=roblox)](https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed/4093890)

[English](https://github.com/weenachuangkud/FastCast2/blob/main/README.md) |
[ภาษาไทย](https://github.com/weenachuangkud/FastCast2/blob/main/README.th.md)

</div>


<br />

**FastCast2** เป็น **ไลบรารี projectile สำหรับ Roblox** ที่ออกแบบมาเพื่อจำลอง projectile ได้เป็น **หลักพัน** โดยไม่ต้องพึ่งการ replicate physics <br />
เนื่องจาก FastCast ไม่ได้รับการดูแลอย่างต่อเนื่องจาก [EtiTheSpirit](https://github.com/EtiTheSpirit) แล้ว repo นี้จึงสานต่อโปรเจกต์นี้ด้วยการอัปเดตและปรับปรุงต่างๆ

---

# ข้อดีของการใช้ FastCast2

- ปรับแต่งได้หลากหลาย
- ไลบรารี projectile ที่ยืดหยุ่น
- รองรับ Parallel scripting
- ใช้งานง่าย ผสานเข้ากับโปรเจกต์ได้สะดวก
- รองรับ Raycast, Blockcast และ Spherecast
- รองรับ BulkMoveTo/Motor6D
- มี castVisualization ในตัว
- มี ObjectCache ในตัว
- มีระบบควบคุม HighFidelitySegment ในตัว
- ออกแบบมาให้ยืดหยุ่นและต่อยอดได้ง่าย
- ช่วยเพิ่มประสิทธิภาพในการพัฒนา
- ประสิทธิภาพสูง
- ใช้งานได้ฟรีทั้งหมด

FastCast2 เป็นโปรเจกต์ open-source และยินดีรับ contribution จากคอมมูนิตี้ <br />
อ่านเพิ่มเติมได้ที่ [FastCast2 devforum](https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed/4093890)

---
# วิธีติดตั้ง

1. ไปที่ [Releases](https://github.com/weenachuangkud/FastCast2/releases) แล้วติดตั้งไฟล์ `.rbxm` จาก release ล่าสุด
2. เปิด Roblox Studio และเปิดโปรเจกต์ของคุณ
3. ไปที่ **File → Import Roblox Model** แล้ว import ไฟล์ `.rbxm`
4. หลังจาก import แล้ว **FastCast2** จะปรากฏใน Workspace ของคุณ
5. ลาก **FastCast2** ไปไว้ใน **ReplicatedStorage**
6. สร้าง Part ขึ้นมาแล้วตั้งค่า:
   - Size เป็น `1, 1, 1`
   - `CanTouch` = false  
   - `CanCollide` = false  
   - `CanQuery` = false  
7. เสร็จแล้ว — พร้อมใช้งาน FastCast2

---

## ติดตั้งด้วย [Wally](https://wally.run/)

1. ตรวจสอบว่าติดตั้ง Wally แล้ว: https://wally.run/install
2. หลังติดตั้ง Wally เรียบร้อย ให้รัน `wally init`
3. จากนั้นในไฟล์ `wally.toml` ใต้หัวข้อ `[dependencies]` ให้คัดลอกและวาง `FastCast2 = "weenachuangkud/fastcast2@0.1.3"`
4. รัน `wally install` แล้วก็พร้อมใช้งานได้เลย

หมายเหตุ: ขั้นตอนนี้ไม่รวมการตั้งค่า rojo

---

# ตัวอย่างโค้ด

การยิง projectile จากหัวตัวละคร (โหมด Serial - ใช้งานง่าย รันบน main thread):

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


-- Serial Caster (รันบน main thread ใช้งานง่ายกว่า)
local Caster = FastCast2.new()
Caster:Init("BulkMoveTo", false) -- movementMode, useObjectCache

-- Events (ตั้งค่าได้ก่อน Init)
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

เปลี่ยนจาก `RaycastFire` เป็น `BlockcastFire` หรือ `SpherecastFire` เพื่อเปลี่ยนรูปแบบการ cast:

```lua
-- Blockcast: ส่งค่า Vector3 size ต่อจาก origin
Caster:BlockcastFire(origin, Vector3.new(2, 4, 2), direction, SPEED, behavior)

-- Spherecast: ส่งค่า radius (number) ต่อจาก origin
Caster:SpherecastFire(origin, 3, direction, SPEED, behavior)
```

### ObjectCache (bullet pooling)

ObjectCache ช่วยนำ instance ของ cosmetic bullet กลับมาใช้ซ้ำ แทนที่จะสร้าง/ทำลายทุกครั้งที่ยิง:

```lua
local Caster = FastCast2.new()
Caster:Init("BulkMoveTo", true, ProjectileTemplate, 500, workspace)
--                                    ^template   ^size  ^holder
```

โดยค่าเริ่มต้น cache จะเตรียม part ไว้ล่วงหน้า 500 ชิ้น และขยายเพิ่มอัตโนมัติเมื่อใช้จนหมด
พร้อมทั้งย้าย part ที่เลิกใช้ไปไว้ที่ CFrame ระยะไกลผ่าน `BulkMoveTo` — ไม่มีภาระจากการสร้าง/ทำลาย instance

### โหมด Parallel (ประสิทธิภาพสูงด้วยหลาย VM)

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
	nil,               -- FastCastEventsModule (ไม่บังคับ)
	false              -- useObjectCache
)

-- Events ทำงานเหมือนกับโหมด Serial
Caster.Hit = function(cast, result, velocity, bullet)
	print("Hit: " .. result.Instance.Name)
end

--[[
	-- ยกเว้น:
	-- Caster.CanPierce
	--> ต้องใช้ FastCastEventsModule แทน
]]

-- การ Fire ก็ใช้แบบเดียวกับ Serial
Caster:RaycastFire(origin, direction, SPEED, behavior)
Caster:BlockcastFire(origin, Vector3.new(2, 4, 2), direction, SPEED, behavior)
Caster:SpherecastFire(origin, 3, direction, SPEED, behavior)
```

<br />

วิธีตั้งค่า [FastCastEventsModule](https://weenachuangkud.github.io/FastCast2/api/TypeDefinitions/#FastCastEventsModule)

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

ลงทะเบียนใช้งานกับ parallel caster ของคุณหลังจาก `Init`:

```lua
Caster:SetFastCastEventsModule(pathTo.FastCastEventsModule)
```

> **หมายเหตุ**: `SetFastCastEventsModule` ใช้ได้เฉพาะกับ parallel caster เท่านั้น ส่วนโหมด serial ให้ตั้งค่า event handler ได้โดยตรง (เช่น `Caster.Hit = function(...)`)

### โหมดการเคลื่อนที่แบบ Motor6D

โหมด Motor6D ใช้ `Motor6D.Transform` เพื่อประสิทธิภาพที่ดีกว่าแทนการใช้ `BulkMoveTo`:

```lua
local Caster = FastCast2.new()
Caster:Init("Motor6D", false) -- movementMode = "Motor6D"
```

ทุก cast ที่ active จะได้รับการเชื่อมต่อ Motor6D โดยอัตโนมัติเมื่อลงทะเบียน และตัดการเชื่อมต่อเมื่อ cleanup
สามารถสลับโหมดได้ระหว่าง runtime:

```lua
Caster:SetMovementModeEnabled(true, "Motor6D")   -- เปิดใช้งาน Motor6D
Caster:SetMovementModeEnabled(true, "BulkMoveTo") -- สลับกลับไปใช้ BulkMoveTo
```

### การจัดการ Cast

แก้ไข cast ที่กำลัง active อยู่ระหว่าง runtime โดยใช้ static method ของ `FastCast`:

```lua
-- อ่านค่าสถานะ
local pos = FastCast2:GetPositionCast(cast)
local vel = FastCast2:GetVelocityCast(cast)
local accel = FastCast2:GetAccelerationCast(cast)

-- แก้ไขสถานะ (จะปรับ trajectory ให้อัตโนมัติ)
FastCast2:SetPositionCast(cast, Vector3.new(0, 50, 0))
FastCast2:SetVelocityCast(cast, Vector3.new(0, 100, 0))
FastCast2:SetAccelerationCast(cast, Vector3.new(0, -workspace.Gravity, 0))

-- การเปลี่ยนแปลงแบบสัมพัทธ์
FastCast2:AddPositionCast(cast, Vector3.new(0, 10, 0))
FastCast2:AddVelocityCast(cast, Vector3.new(0, 20, 0))
FastCast2:AddAccelerationCast(cast, Vector3.new(0, -50, 0))

-- ยกเลิก cast ก่อนเวลา (จะยิง event CastTerminating และ cleanup ให้)
FastCast2:TerminateCast(cast)
```

> **เคล็ดลับ**: ในโหมด parallel ให้เรียก `Caster:SyncChangesToCast(cast)` หลังจากแก้ไขค่า เพื่อส่งการเปลี่ยนแปลงเข้าไปยัง worker VM

### -> เริ่มต้นใช้งานได้ที่ [เอกสาร FastCast2](https://weenachuangkud.github.io/FastCast2/docs/api-reference)

---

# ผู้อยู่เบื้องหลัง FastCast2 (Contributors)
- [CK06](https://github.com/weenachuangkud): นักพัฒนาหลัก, ผู้ดูแลโปรเจกต์, นักออกแบบกราฟิก
- [Naymmmm](https://github.com/Naymmmm): ผู้ดูแลโปรเจกต์ (ไม่ได้ใช้งานแล้ว)
- [EtiTheSpirit](https://github.com/EtiTheSpirit): ผู้พัฒนาต้นฉบับ
- [Per2iako](https://github.com/Per2iako): ผู้ดูแลโปรเจกต์

# ขอบคุณเป็นพิเศษ

### ขอบคุณเป็นพิเศษแก่ผู้คนต่อไปนี้จาก [เซิร์ฟเวอร์ Discord ของ Suphi Kaner](https://youtube.com/@5uphi?si=gWWZ6RNqaEYx26az):

- @avibah — ที่ช่วยสร้าง VMDispatcher
- @ace9b472eeec4f53ba9e8d91bo87c636 — สำหรับคำแนะนำ ฟีดแบ็ก และไอเดียต่างๆ
- @23sinek345 — สำหรับการรีวิวโค้ด การพูดคุยเรื่อง benchmark และข้อเสนอแนะในการปรับปรุง

และขอบคุณทุกคนในเซิร์ฟเวอร์ที่ช่วยเหลือกันมาตลอด

โดยรวมแล้ว ฟีดแบ็กจากคอมมูนิตี้มีส่วนสำคัญอย่างมากต่อการมีอยู่และพัฒนาการของ FastCast2 ไอเดีย บทสนทนา และแรงบันดาลใจหลายอย่างมาจากการพูดคุยกันในเซิร์ฟเวอร์ Discord ของ Suphi Kaner FastCast2 คงไม่มีวันนี้ได้เลยหากไม่ได้รับการสนับสนุน ฟีดแบ็ก และความช่วยเหลือจากคอมมูนิตี้นี้

### ขอบคุณเป็นพิเศษแก่ผู้คนต่อไปนี้จาก [The Revolutionary Computer Union](https://www.roblox.com/communities/336090209/TRCU-The-Revolutionary-Computer-Union#!/about):
- [@nerd0ne](https://github.com/nerd0ne) — ที่ชี้ให้เห็นปัญหา Wally setup

# Dependency
- [ObjectCache](https://devforum.roblox.com/t/objectcache-a-modern-blazing-fast-model-and-part-cache/3104112)
- [VMsDispatcher](https://github.com/weenachuangkud/VMsDispatcher)

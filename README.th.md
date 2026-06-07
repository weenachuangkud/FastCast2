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

> ความต่อเนื่องที่ไม่ใช่อย่างเป็นทางการของ FastCast สำหรับ Roblox

**เวอร์ชันที่ปรับปรุงแล้วของ [FastCast](https://etithespir.it/FastCastAPIDocs/)** พร้อมด้วย **การเขียนโปรแกรมแบบขนาน**, **ส่วนขยายเพิ่มเติม**, และ **พิมพ์แบบคงที่**. <br /> **ไลบรารีโปรเจกไทล์ที่ทรงพลังและทันสมัย**

**FastCast2** เป็น **ไลบรารีโปรเจกไทล์ของ Roblox** ที่ขับเคลื่อนโดย [VMsDispatcher](https://github.com/weenachuangkud/VMsDispatcher) ออกแบบมาเพื่อจำลอง**หลายพันโปรเจกไทล์** โดยไม่ต้องพึ่งพาการจำลองฟิสิกส์

เนื่องจาก FastCast ไม่ได้รับการบำรุงรักษาอย่างแข็งขันโดย [EtiTheSpirit](https://github.com/EtiTheSpirit) ที่ไม่บังคับ ที่เก็บนี้จึงดำเนินโครงการต่อไปด้วยการปรับปรุงและปรับตัว

<br />

# ข้อดีของการใช้ FastCast2

- ปรับแต่งได้สูง
- ไลบรารีโปรเจกไทล์อเนกประสงค์
- การสนับสนุนการเขียนโปรแกรมแบบขนาน
- ใช้งานและรวมเข้าได้ง่าย
- รองรับ Raycast และ Blockcast, Spherecast
- รองรับ BulkMoveTo/Motor6D
- มี castVisualization ในตัว
- มี ObjectCache ในตัว
- มีการควบคุม HighFidelitySegment ในตัว
- ออกแบบที่ยืดหยุ่นและขยายได้
- ปรับปรุงผลผลิตการพัฒนา
- ประสิทธิภาพสูง
- ฟรีทั้งหมด

FastCast2 เป็นโครงการโอเพนซอร์ส และการมีส่วนร่วมจากชุมชนได้รับการต้อนรับ <br />
อ่านเพิ่มเติมใน [FastCast2 devforum](https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed/4093890)

---
# คู่มือการติดตั้ง


1. ไปที่ [Releases](https://github.com/weenachuangkud/FastCast2/releases) และติดตั้งไฟล์ `.rbxm` จากรุ่นล่าสุด
2. เปิด Roblox Studio และเปิดโครงการใดๆ
3. ไปที่ **File → Import Roblox Model** และนำเข้าไฟล์ `.rbxm`
4. หลังจากนำเข้า **FastCast2** จะปรากฏในพื้นที่ทำงานของคุณ
5. ลาก **FastCast2** ไปที่ **ReplicatedStorage**
6. สร้างส่วน (Part) และตั้งค่า:
   - ขนาดเป็น `1, 1, 1`
   - `CanTouch` = false  
   - `CanCollide` = false  
   - `CanQuery` = false  
7. เสร็จแล้ว — คุณพร้อมที่จะใช้ FastCast2

---

## ติดตั้งด้วย Rojo

1. ติดตั้ง [Rojo CLI](https://rojo.space/docs/installation/) สำหรับระบบของคุณ
2. โคลนที่เก็บนี้:
```bash
   git clone https://github.com/weenachuangkud/FastCast2.git
   cd FastCast2
   rm -rf .git
```
3. ซิงค์กับ Roblox:
```bash
   rojo sync -o <place-name>
```
   หรือให้บริการแบบสดด้วย:
```bash
   rojo serve
```
   จากนั้นเชื่อมต่อใน Roblox Studio ผ่าน **Studio → Plugins → Rojo**

---

# ตัวอย่างโค้ด

ยิงโปรเจกไทล์จากหัวของคุณ (โหมดอนุกรม - ง่ายกว่า, เธรดหลัก):

```lua
-- บริการ (Services)
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ต้องการ (Requires)
local FastCast2 = require(Rep:WaitForChild("FastCast2"))
local FastCastEnums = require(Rep:WaitForChild("FastCast2"):WaitForChild("FastCastEnums"))

-- ค่าคงที่
local SPEED = 500

-- ตัวแปร
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local Head = character:WaitForChild("Head")
local Mouse = player:GetMouse()

local ProjectileContainer = workspace:WaitForChild("Projectiles")
local ProjectileTemplate = Rep:WaitForChild("Projectile")

-- พารามิเตอร์การแคสต์ (CastParams)
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- พฤติกรรม (Behavior) - FastCastBehavior
local behavior = FastCast2.newBehavior()
behavior.MaxDistance = 1000
behavior.RaycastParams = CastParams
behavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
behavior.HighFidelitySegmentSize = 1
behavior.Acceleration = Vector3.new(0, -workspace.Gravity/2.3, 0)
behavior.CosmeticBulletContainer = ProjectileContainer
behavior.CosmeticBulletTemplate = ProjectileTemplate


-- โปรแกรมทำการแคสต์แบบอนุกรม (Serial Caster) - ทำงานบนเธรดหลัก ง่ายกว่า
local Caster = FastCast2.new()
Caster:Init("BulkMoveTo", false) -- โหมดการเคลื่อนไหว, ใช้ ObjectCache

-- เหตุการณ์ (Events) - สามารถตั้งค่าได้ก่อน Init
Caster.Hit = function(cast, result, velocity, bullet)
	print("ตี: " .. result.Instance.Name)
end

-- ยิง
local function fire()
	local origin = Head.Position
	local direction = (Mouse.Hit.Position - origin).Unit
	Caster:RaycastFire(origin, direction, SPEED, behavior)
end

-- อินพุต
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fire()
	end
end)
```

### Blockcast & Spherecast

สลับ `RaycastFire` ไปยัง `BlockcastFire` หรือ `SpherecastFire` เพื่อเปลี่ยนประเภทการแคสต์:

```lua
-- Blockcast: ส่ง Vector3 ขนาดหลังจากจุดกำเนิด
Caster:BlockcastFire(origin, Vector3.new(2, 4, 2), direction, SPEED, behavior)

-- Spherecast: ส่งหมายเลขรัศมีหลังจากจุดกำเนิด
Caster:SpherecastFire(origin, 3, direction, SPEED, behavior)
```

### ObjectCache (การรีไซเคิลกระสุน)

ObjectCache นำอินสแตนซ์กระสุนเครื่องแบบกลับมาใช้ใหม่แทนการสร้าง/ลบเมื่อทำการยิง:

```lua
local Caster = FastCast2.new()
Caster:Init("BulkMoveTo", true, ProjectileTemplate, 500, workspace)
--                                    ^template   ^size  ^holder
```

แคชจัดสรร 500 ส่วนล่วงหน้าตามค่าเริ่มต้น, ขยายโดยอัตโนมัติเมื่อหมด, และย้ายส่วนที่ตกลงมาไปยัง CFrame ห่างไกล ผ่าน `BulkMoveTo` — ไม่มีค่าใช้จ่ายในการสร้าง/ลบอินสแตนซ์

### โหมดขนาน (ประสิทธิภาพสูงพร้อม VM หลายตัว)

```lua
local Caster = FastCast2.newParallel()
Caster:Init(
	4,                 -- จำนวนคนงาน (numWorkers)
	workspace,         -- ที่อยู่ของโฟลเดอร์ VM
	"FastCastVMs",     -- ชื่อโฟลเดอร์ VM
	workspace,         -- ที่อยู่ของคอนเทนเนอร์
	"VMContainer",     -- ชื่อคอนเทนเนอร์
	"VM",              -- ชื่อ VM
	"BulkMoveTo",      -- โหมดการเคลื่อนไหว
	nil,               -- FastCastEventsModule (ไม่บังคับ)
	false              -- ใช้ ObjectCache
)

-- เหตุการณ์ทำงานเหมือนกับโหมดอนุกรม
Caster.Hit = function(cast, result, velocity, bullet)
	print("ตี: " .. result.Instance.Name)
end

--[[
	-- ยกเว้น:
	-- Caster.CanPierce
	--> คุณจะต้องใช้ FastCastEventsModule สำหรับสิ่งนั้น
]]

-- ยิงเหมือนกับโหมดอนุกรม
Caster:RaycastFire(origin, direction, SPEED, behavior)
Caster:BlockcastFire(origin, Vector3.new(2, 4, 2),

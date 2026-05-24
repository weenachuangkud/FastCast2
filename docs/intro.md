---
sidebar_position: 1
---

# Introduction

**FastCast2** is a **Roblox projectile library** powered by [VMsDispatcher](https://github.com/weenachuangkud/VMsDispatcher) designed to simulate **thousands** of projectiles without relying on physics replication.

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

<br />

# Quick start

```lua
local FastCast2 = require(ReplicatedStorage:WaitForChild("FastCast2"))

local caster = FastCast2.new()
caster:Init("BulkMoveTo", false)

caster.Hit = function(cast, result, velocity, bullet)
	print("Hit:", result.Instance)
end

-- Raycast, Blockcast, or Spherecast
caster:RaycastFire(origin, direction, 500, behavior)

-- Blockcast: caster:BlockcastFire(origin, Vector3.new(2,2,2), direction, 500, behavior)
-- Spherecast: caster:SpherecastFire(origin, 3, direction, 500, behavior)
```

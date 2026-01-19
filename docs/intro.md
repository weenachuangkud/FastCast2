---
sidebar_position: 1
---

# Introduction

**FastCast2** is a projectile simulation library powered by **VMsDispatcher**, designed to simulate projectiles without relying on physics replication. This approach ensures consistent behavior, improved performance, and reduced network overhead in multiplayer environments.

### Benefits of using FastCast2

* Highly customizable projectile behavior
* Ability to communicate between the main thread and worker threads, with fine-grained control over execution (at the cost of additional performance overhead when misused)
* Parallel scripting support for improved scalability
* Simple and developer-friendly API
* Support for both raycasting and blockcasting
* BulkMoveTo integration for efficient cosmetic updates
* Built-in ObjectCache module to reduce memory allocations

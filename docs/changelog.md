---

## sidebar_position: 3

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

> **Version support**
>
> FastCast2 **1.0.0 and newer** are the current and supported versions.
>
> Versions **<1.0.0** are legacy releases. They are no longer actively maintained or documented, but remain available through GitHub Releases for existing projects and historical use.

---

## [Unreleased]

### Added

* Automated testing by @Naymmmm
* Better performance benchmarks by @Naymmmm
* `"Config.SimulationMode"` (PerFrame/Fixed) and `"CosmeticUpdateInterval"` by @Naymmmm
* `"RAY_SEARCH_OFFSET"` for pierce prevention
* `"cast.Mode"`
* **`Signal`** - lightweight synchronous event dispatcher (`src/Signal.luau`) used for Caster events instead of `BindableEvent`
* Caster events (`Hit`, `Pierced`, `LengthChanged`, `CastFire`, `CastTerminating`) are now Signals supporting multiple listeners, `Once`, `Wait`, `Disconnect`, `DisconnectAll`, and `Destroy`

### Fixes

* BenchmarkClient/BenchmarkServer
* Various simulation logic bugs
* `"CastTerminating"` callback/cleanup issues (Serial now invokes the user callback before cleanup)
* Pierce prevention issues (`"RAY_SEARCH_OFFSET"` only applies after a pierce)
* Motor6D movement issues
* Parallel client initialization (Init is now retried until every actor is ready)
* Refactor regressions found by the test suite
* An annoying warning
* Duplicate Serial cast unregister cleanup
* Parallel behavior snapshots now properly deep-copy nested configuration data

### Changes

* `"SerialSimulation"` is no longer OOP-based and no longer creates a per-instance connection.
* Replaced `"BindableEvent"` with Signal module (supports multiple listeners, function assignment still works)
* Simplified `"FastCastParallel:Init"` API
* Added `"BindToSimulation"`
* Consolidated `"TerminateCast"`
* Parallel fire requests are now batched into one message per worker per frame
* Improved Serial/Parallel event systems
* You can now `Caster.Event:Connect(function() ... end)` or `Caster.Event = function() ... end`
* Parallel workers now batch all queued events into a single `Output` message per frame instead of firing one message per event
* `CanPierce` remains a single function because it has to return a boolean by @Naymmmm
* A lot of optimizations
* Major code improvements
* Improved documentation

### Removed

* Built-in ObjectCache
  (See:

  * YouTube video: https://www.youtube.com/watch?v=YyQi82TzYL4&t=61s
  * DevForum post: https://devforum.roblox.com/t/fastcast2-an-improved-version-of-fastcast-with-parallel-scripting-more-extensions-and-statically-typed-a-powerful-modern-projectile-library/4093890/544?u=mawin_ck
    )

* Automatic `CosmeticBulletTemplate` cleanup
  (So you can have more control over `CosmeticBulletTemplate`)

### Cancelled

* Dynamic RunService event configuration for Caster
  (Because you can simply edit the FastCast2 code if you want to change the specific RunService event)

* Debugger GUI for benchmarking and testing
  (Might add this back)

---

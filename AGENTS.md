# AGENTS.md

## Project Overview

FastCast2 is a Roblox projectile library written in Luau, providing high-performance raycasting, blockcasting, and spherecasting with parallel scripting support. It is an unofficial continuation of the original FastCast library.

- **Language**: Luau (Roblox)
- **Build Tool**: Rojo (`rojo sync`, `rojo serve`)
- **Documentation**: Moonwave
- **Repository**: https://github.com/weenachuangkud/FastCast2

## Development Commands

- **Sync to Roblox**: `rojo sync -o <place-name>`
- **Serve live**: `rojo serve` (then connect via Studio → Plugins → Rojo)
- **Build docs**: `moonwave build`
- **Publish docs**: `moonwave build --publish`

## Project Structure

```plaintext
src/
├── init.luau                    # Entry: FastCast (static), FastCastSerial, FastCastParallel
├── BaseCastSerial.luau          # Serial: cast handler, routes events to SerialSimulation
├── BaseCastParallel.luau        # Parallel: runs inside each Actor VM, casts per-VM
├── SerialSimulation.luau        # Serial: SoA physics engine, single-threaded
├── ParallelSimulation.luau      # Parallel: SoA physics engine, one per Actor VM
├── ActiveCast.luau              # Cast data container (used by both modes)
├── ObjectCache.luau             # Cosmetic bullet part pooling
├── Motor6DCache.luau            # Motor6D pooling for Transform movement mode
├── TypeDefinitions.luau         # All Luau type definitions
├── FastCastEnums.luau           # Enum values (HighFidelityBehavior, CastType)
├── Config.luau                  # Debug logging flags
├── DefaultConfigs.luau          # Default FastCastBehavior values
└── FastCastVMs/
    ├── init.luau               # Dispatcher: creates/manages Actor VMs, load balancing
    ├── ClientVM.client.luau    # Client-side Actor script
    ├── ServerVM.server.luau    # Server-side Actor script
    └── *.meta.json             # Rojo metadata (Enabled = false)
```

## Testing

There are no automated tests. Testing is manual via Roblox Studio.

## Code Style

- Luau static typing throughout
- PascalCase for types, camelCase for variables/functions
- Two-space indentation
- SoA (Structure of Arrays) pattern for simulation data

## Agent Skills

To understand specific project workflows, refer to the skills defined here:
- @skills/FastCast2/architecture.md

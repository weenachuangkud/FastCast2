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

```
src/FastCast2/           # Main source code (synced to ReplicatedStorage)
.default.project.json    # Rojo project configuration
```

## Testing

There are no automated tests in this project. Testing is done manually through Roblox Studio.

## Code Style

- Uses Luau static typing
- Follows standard Luau conventions (PascalCase for types, camelCase for variables)
- Modules are required via `require(path)`

## Important Notes

- Requires Roblox Studio to run/test code
- Parallel casting requires `VMsDispatcher` module
- Cosmetic bullets should have `CanTouch = false`, `CanCollide = false`, `CanQuery = false`

## Agent Skills
To understand specific project workflows, refer to the skills defined here:
- @skills/architecture.md
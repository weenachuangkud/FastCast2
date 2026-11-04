# Testing FastCast2

## Run the automated suite

From the repository root, run:

```sh
npm test
# or
lune run tests/run.luau
```

The runner builds the test place, runs it in Roblox Studio through `run-in-roblox`, prints the functional-test summary and benchmark results, and uploads the report to [paste.shellworks.dev](https://paste.shellworks.dev). See [`tests/README.md`](tests/README.md) for prerequisites, flags, and project layout.

## Functional test checklist

The functional suite covers the shared public API and core cast lifecycle. Use this checklist when reviewing coverage or testing manually in Studio.

### Caster lifecycle and events

- [ ] Initialize, create, and destroy a caster.
- [ ] Stop simulation updates with an active cast, then call `FastCast.Init()` and confirm the cast resumes.
- [ ] Fire Raycast, Blockcast, and Spherecast casts; confirm each reaches a target and terminates.
- [ ] Confirm enabled event callbacks fire: `CastFire`, `LengthChanged`, `Hit`, `Pierced`, `CanPierce`, and `CastTerminating` where applicable.
- [ ] Confirm Signals support multiple listeners and connection disconnection; check `Once`, `Wait`, and `DisconnectAll`.
- [ ] Verify event configuration can disable callback channels; for example, setting `UseLengthChanged = true` enables the `LengthChanged` callback.
- [ ] Verify `CanPierce` and `Pierced` when a cast is allowed through an instance.
- [ ] Verify `OnStep` runs before movement when enabled and can change a cast's trajectory.

### Behavior configuration and movement

- [ ] Check `FastCast.newBehavior()` defaults and confirm nested configuration tables are independent between behaviors.
- [ ] Switch the caster's movement mode and confirm the selected mode is applied.
- [ ] Manipulate cast position, velocity, and acceleration using the public cast-manipulation methods.
- [ ] Confirm `RaycastParams` filters excluded instances and the cast can hit the next eligible target.
- [ ] Confirm `MaxDistance` terminates a cast without reporting a hit when no target is reached first.
- [ ] Confirm `MaxLifetime` termination, including a zero lifetime.
- [ ] Confirm paused casts stop advancing and resume without catching up on paused time.
- [ ] Exercise all high-fidelity modes: `Default`, `Automatic`, and `Always`, including hit resolution and maximum-distance termination.

### Cosmetic projectiles

- [ ] Confirm `CosmeticBulletTemplate` is cloned into `CosmeticBulletContainer` when `CloneTemplate` is enabled.
- [ ] Confirm `CloneTemplate = false` uses the supplied cosmetic instance.
- [ ] Confirm the cast ignores its own cosmetic container when configured to do so.
- [ ] Remember: cosmetic projectile lifetime and cleanup are caller-owned. FastCast2 does not automatically destroy projectiles or return them to a cache.

### Cast data

- [ ] Check cast data exposed by `CastFire` and the cast's type, trajectory, ray information, and user data.
- [ ] Confirm firing methods return the active cast.
- [ ] Confirm cast state can be changed while the cast is active and that changes affect subsequent simulation as expected.

## Benchmarks

The automated runner also reports benchmark results. Use them to compare performance changes under the same environment and settings; do not treat a benchmark result alone as proof that functional behavior is correct.

## Manual testing notes

- Run the suite in Roblox Studio; static checks alone do not verify runtime behavior.
- Focus on observable public API behavior rather than re-testing argument validation and every internal edge case.
- If a test fails, inspect the functional-test output and the uploaded report before treating the change as ready.
- API reference: [FastCast2 API](https://weenachuangkud.github.io/FastCast2/docs/api-reference/).

# Testing FastCast2

The checklist below is covered by the automated suite. Run it with one command
from the repository root:

```sh
npm test
# or
lune run tests/run.luau
```

The runner builds the test place, runs it in Roblox Studio via
`run-in-roblox`, prints a functional-test summary and a benchmark table, and
uploads the full report to [paste.shellworks.dev](https://paste.shellworks.dev).
See [`tests/README.md`](tests/README.md) for prerequisites, flags, and the
project layout.

The same cases can still be verified by hand if Studio automation is not
available.

### Caster
1. Initialization
2. Basic raycast/blockcast/spherecast firing
3. All [events](https://weenachuangkud.github.io/FastCast2/docs/api-reference/#112-events) should be able to works
4. ObjectCache
5. MovementMode
6. Cast Manipulation
7. Repeat the same tests above for parallel version
8. SetFastCastEventsModule (Parallel)
9. SyncChangesToCast (Parallel)
### FastCastBehavior
- https://weenachuangkud.github.io/FastCast2/docs/api-reference/#2-fastcastbehavior
### ActiveCastData
- https://weenachuangkud.github.io/FastCast2/docs/api-reference/#3-activecastdata
### [FastCastEventsModule](https://weenachuangkud.github.io/FastCast2/docs/api-reference/#4-fastcasteventsmodule) (Parallel)
- All [events](https://weenachuangkud.github.io/FastCast2/docs/api-reference/#112-events) should be able to works
- [FastCastEventsModuleConfig](https://weenachuangkud.github.io/FastCast2/docs/api-reference/#event-configuration)
### [High-Fidelity Behavior](https://weenachuangkud.github.io/FastCast2/docs/api-reference/#5-high-fidelity-behavior)
- Modes (Default, Automatic, Always)
- HighFidelitySegmentSize

### NOTE

- You do not need to check whether the arguments are correct, handle edge cases, etc., as these are already handled (and should be handled) inside the code.
- If you pass all the tests without any errors, and the results aren't off, it should pretty much be working fine.

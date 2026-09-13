# Shiftline

A Luau game prototype combining car ownership, three job minigames, a generated hub, and a timed race queue.

> Reliability improvements are isolated on `fix/reliability-and-validation`. See [changes and testing](docs/RELIABILITY.md). The main branch remains unchanged.

## Implemented systems

- **Economy:** player cash, owned cars, current selection, autosave, and shutdown saves through a shared data module.
- **Jobs:** Card Matching, Quick Math, and Pattern Memory interfaces, with server-side session timing and score-range checks, payouts, and saved cooldown timestamps.
- **Garage and dealerships:** catalog browsing, server-priced purchases, ownership checks, and in-world pickup menus.
- **Hub generation:** randomized dealership and job-station placement, with tagged interaction signs.
- **Race queue:** join/leave controls, a five-minute server timer, groups of up to six real players, and a requested bot count for the future race engine.

## Status

This repository contains the source scripts for a **work-in-progress prototype**, not a complete Roblox place export. The race engine, playable race scene, bot implementation, and vehicle spawning/driving system are not included. Car selection updates saved data; it does not spawn a vehicle.

## Start here

1. Follow [Studio setup](docs/SETUP.md) to place the scripts.
2. Read [architecture and current limitations](docs/ARCHITECTURE.md).
3. See [source versions](docs/VERSIONS.md) for the selected files and archived alternatives.

## Layout

| Directory | Roblox destination | Contents |
| --- | --- | --- |
| `src/ReplicatedStorage` | ReplicatedStorage | Shared car configuration |
| `src/ServerScriptService` | ServerScriptService | Data, economy, jobs, map, and queue logic |
| `src/StarterPlayer/StarterPlayerScripts` | StarterPlayer > StarterPlayerScripts | Garage, pickup, minigame, and queue interfaces |

Descriptive script names are retained because modules are referenced by name. Upload suffixes such as `_2` and `(1)` are removed from the main source tree. `.server.lua`, `.client.lua`, and `.lua` distinguish Scripts, LocalScripts, and ModuleScripts.

## Review status

All 17 Luau source files compile. The automated suite covers profile/economy failures and actual job handlers with mocked services. Run `npm ci` and `npm test` with Node.js 20+ to reproduce these checks. Roblox Studio execution and multiplayer behavior have not been tested in this environment. See the setup checklist before treating this prototype as release-ready.

## Author

[Lakshmi Muppana](https://github.com/L4K5HM1)

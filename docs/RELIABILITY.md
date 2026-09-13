# Reliability branch

This work belongs to `fix/reliability-and-validation`. It does not change `main` or the archived source branches. Import all scripts from this branch together: job clients now send the server-issued session token.

## Changes

- Loads use `UpdateAsync` to claim a 180-second profile lease. Autosaves renew it every 60 seconds. Another session cannot claim a live lease; an expired or displaced session cannot write over the newer owner.
- Failed or corrupt loads disconnect the player and are never cached as new defaults. Missing fields are migrated without calling a table-only copy operation on scalars.
- Saves are serialized per player, with snapshot copies. Leave and shutdown release ownership; shutdown starts saves concurrently with a bounded wait.
- Currency methods reject negative, fractional, non-finite and overflowing amounts. Purchases update cash and ownership together without yielding.
- Economy remotes validate names and throttle requests. Car selection checks the player's distance to the correct dealership; buying from the garage remains available remotely by design.
- Job starts check data readiness, station proximity, cooldown and existing sessions. Unique tokens prevent old results from completing a different session. Cancellation, expiry, invalid score and replay paths are rejected.
- Minigame interfaces wait for accepted starts, handle connection errors, cancel on close and guard delayed callbacks against a newly opened game.
- Map generation sets attributes before publishing CollectionService tags, preventing prompt listeners from seeing incomplete metadata.

## Testing

```sh
npm ci
npm test
```

Node.js 20+ is needed only for development tests. `luau-web` runs the real Luau compiler and runtime in WebAssembly. The suite compiles every source script, executes 10 profile/economy regression cases, and exercises actual job handlers using service doubles. It does not emulate Roblox networking, physics, DataStore throttling or the full client UI.

Roblox Studio acceptance testing is **still required**; follow [SETUP.md](SETUP.md). Verify all three minigames, close/reopen during animations, cooldown rejection, failed loads, leaving during load/save, two-client interactions and persistence in an isolated test experience.

## Operational limits

- Job outcomes are still calculated on clients. Tokens, timing, distance and numeric validation reject malformed or stale submissions; they do not prove that a plausible score was earned. Server-authoritative challenges are future work.
- A crashed server's lock can delay rejoining for up to 180 seconds. Progress since the last successful save can be lost. Retries and leases do not promise zero data loss.
- Do not mix these writers with older `SetAsync` servers on the same data store. Older code does not honor leases. A future rollout must retire those servers first and be tested against separate data.
- No driving/vehicle spawning, playable race engine, bot AI or race rewards are added here.

The persistence approach follows [Roblox's DataStore guidance](https://create.roblox.com/docs/cloud-services/data-stores): protected network calls and non-yielding `UpdateAsync` callbacks. Server checks follow [Roblox security guidance](https://create.roblox.com/docs/scripting/security/server-side-detection). This is a reviewed prototype branch, not a production-readiness certification.

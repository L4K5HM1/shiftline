# Architecture

`CarConfig` supplies catalog prices and abilities. `EconomyBootstrap` creates economy remotes and connects player lifecycle events to `PlayerDataService`.

`PlayerDataService` owns loaded profiles, readiness and lifecycle handling. `ProfileStore` contains independently testable migration, currency transactions and session-lease rules. It receives an injected update function; the service supplies retry-wrapped DataStore `UpdateAsync` calls. Client snapshots omit session metadata.

`MapGenerator` builds the hub and assigns attributes before publishing tags. `DealershipInteraction` and `JobStationInteraction` attach prompts. `InteractionGuard` checks distance and throttles requests on the server.

`JobMinigameService` issues session tokens, rejects overlapping starts, validates elapsed time and integer score bounds, and records payouts and cooldowns. Clients wait for acceptance and cancel abandoned sessions. Scores themselves remain client-reported.

`RaceQueueService` maintains an ordered queue and membership lookup, forms groups on a timer, and emits a race-start event. Its timer is per server, not globally synchronized. Race notifications remain the endpoint of this prototype.

Read [reliability changes, testing and remaining limitations](RELIABILITY.md) before importing or merging this branch. Roblox Studio and multiplayer behavior have not been verified in this environment.

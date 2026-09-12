# Architecture

`CarConfig` supplies catalog prices and abilities. `EconomyBootstrap` creates economy remotes and connects player lifecycle events to `PlayerDataService`. The data module caches player records and saves them through DataStoreService.

`MapGenerator` builds the hub. `DealershipInteraction` and `JobStationInteraction` watch CollectionService tags and attach prompts. Client interfaces receive the prompt events and call the economy or job remotes.

`JobMinigameService` tracks sessions, checks timing and score ranges, calculates payouts, and records cooldowns through `PlayerDataService`. The minigames themselves run on the client.

`RaceQueueService` maintains an ordered queue and membership lookup, forms groups on a timer, and emits a race-start event. `RaceQueueBootstrap` forwards updates to the client UI. Its timer is per server, not globally synchronized across Roblox servers.

## Known limitations from source review

- No race engine, vehicle spawning, actual bots, or race rewards are included.
- Job scores are client-reported. Timing/range checks are partial validation, not proof of completion. Non-finite and fractional scores need explicit rejection.
- Minigame clients ignore the `StartJob` success result, so a cooldown rejection can still open a game.
- Failed data reads can fall back to defaults that may later overwrite saved data. Existing code uses `SetAsync` without session locking. Resolve this before using valuable player data.
- Default-field backfilling calls a table-copy helper on scalar defaults as well as tables; missing scalar fields can cause an error.
- Generated trigger tags are added before their attributes. A running tag listener can observe missing attributes and skip prompt creation; attribute assignment should precede tagging.
- Purchase and selection handlers need stronger argument validation. Job start and car selection do not validate world proximity on the server.
- The shared `GetPlayerData` remote can be queried before loading finishes; client handling and startup order need Studio testing.

These findings are documented rather than silently rewriting the supplied game behavior during repository organization.

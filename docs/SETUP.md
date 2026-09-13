# Roblox Studio setup

Use a separate test place. This is a scripts-only import; no `.rbxl` or `.rbxlx` place file was supplied.

1. Create a baseplate place in Roblox Studio.
2. Put the contents of `src/ReplicatedStorage/CarConfig.lua` into a ModuleScript named `CarConfig` in ReplicatedStorage.
3. In ServerScriptService, create a ModuleScript for each plain `.lua` file (`PlayerDataService`, `ProfileStore`, `InteractionGuard`, `RaceQueueService`) and a Script for each `.server.lua` file. Copy the matching code into each. Remove filename extensions from Studio instance names.
4. In StarterPlayer > StarterPlayerScripts, create one LocalScript per `.client.lua` file and copy its code. Use the filename without `.client.lua` as its instance name.
5. Do not insert multiple archived versions of the same script. Server scripts create the remote objects at runtime; the map script generates the prototype hub.
6. For persistence testing, publish a separate test experience and configure Studio API access in its settings. Do not test against live player saves. Failed loads disconnect the player instead of substituting default data. For a local session without persistence, explicitly add a boolean `UseMockData` attribute set to `true` on the `PlayerDataService` ModuleScript; this setting is honored only in Studio. See [reliability notes](RELIABILITY.md).
7. Start a Studio play session and check Output for errors.

## Manual acceptance checklist (not yet executed)

- Verify the hub, dealership prompts, and all three job prompts appear.
- Play each minigame and inspect its payout and cooldown behavior.
- Verify insufficient funds and duplicate car purchases are rejected.
- Select an owned car through the dealership pickup menu.
- Move the garage panel; minimize and restore the queue panel.
- Use multiple Studio clients to test join, leave, disconnect, and queue grouping.
- In the isolated persistence test place, leave and rejoin to check saved cash, ownership, current car, and cooldowns.
- Test narrow screen sizes and review Output throughout.

Race-start notifications are the current endpoint; a playable race is not included.

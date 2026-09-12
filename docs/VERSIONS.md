# Source versions

`main` selects the expanded UI variants, accessible-sign map variant, and the matching persistent-cooldown job/data modules. Selection is based on code differences, not upload suffix chronology. Original code bytes are retained.

`archive/original-uploads` preserves all 28 files together. Other `archive/` branches are file snapshots over the selected source tree, not supported alternative releases. Some older modules are incompatible with newer callers; use these branches for comparison, not playtesting. Exact duplicate uploads share a commit while retaining a branch name for each uploaded copy. No artificial past development history is implied.

| Uploaded file | Selected path | Branch |
| --- | --- | --- |
| `CarConfig.lua` | `src/ReplicatedStorage/CarConfig.lua` | `main` |
| `CarPickupUI.client.lua` | `src/StarterPlayer/StarterPlayerScripts/CarPickupUI.client.lua` | `main` |
| `CardMatchingUI.client.lua` | `src/StarterPlayer/StarterPlayerScripts/CardMatchingUI.client.lua` | `archive/cardmatchingui-client` |
| `CardMatchingUI.client_1.lua` | `src/StarterPlayer/StarterPlayerScripts/CardMatchingUI.client.lua` | `main` |
| `CardMatchingUI.client_2.lua` | `src/StarterPlayer/StarterPlayerScripts/CardMatchingUI.client.lua` | `archive/cardmatchingui-client-2` |
| `CardMatchingUI.client_3.lua` | `src/StarterPlayer/StarterPlayerScripts/CardMatchingUI.client.lua` | `archive/cardmatchingui-client-3` |
| `DealershipInteraction.server.lua` | `src/ServerScriptService/DealershipInteraction.server.lua` | `main` |
| `EconomyBootstrap.server.lua` | `src/ServerScriptService/EconomyBootstrap.server.lua` | `main` |
| `GarageUI.client.lua` | `src/StarterPlayer/StarterPlayerScripts/GarageUI.client.lua` | `archive/garageui-client` |
| `GarageUI.client_1.lua` | `src/StarterPlayer/StarterPlayerScripts/GarageUI.client.lua` | `archive/garageui-client-1` |
| `GarageUI.client_2.lua` | `src/StarterPlayer/StarterPlayerScripts/GarageUI.client.lua` | `main` |
| `JobMinigameService.server(1).lua` | `src/ServerScriptService/JobMinigameService.server.lua` | `main` |
| `JobMinigameService.server.lua` | `src/ServerScriptService/JobMinigameService.server.lua` | `archive/jobminigameservice-server` |
| `JobMinigameService.server_1.lua` | `src/ServerScriptService/JobMinigameService.server.lua` | `archive/jobminigameservice-server-1` |
| `JobMinigameService.server_2.lua` | `src/ServerScriptService/JobMinigameService.server.lua` | `archive/jobminigameservice-server-2` |
| `JobMinigameService.server_3.lua` | `src/ServerScriptService/JobMinigameService.server.lua` | `archive/jobminigameservice-server-3` |
| `JobStationInteraction.server.lua` | `src/ServerScriptService/JobStationInteraction.server.lua` | `main` |
| `MapGenerator.server.lua` | `src/ServerScriptService/MapGenerator.server.lua` | `archive/mapgenerator-server` |
| `MapGenerator.server_1.lua` | `src/ServerScriptService/MapGenerator.server.lua` | `archive/mapgenerator-server-1` |
| `MapGenerator.server_2.lua` | `src/ServerScriptService/MapGenerator.server.lua` | `main` |
| `PatternMemoryUI.client.lua` | `src/StarterPlayer/StarterPlayerScripts/PatternMemoryUI.client.lua` | `main` |
| `PlayerDataService(1).lua` | `src/ServerScriptService/PlayerDataService.lua` | `main` |
| `PlayerDataService.lua` | `src/ServerScriptService/PlayerDataService.lua` | `archive/playerdataservice` |
| `QuickMathUI.client.lua` | `src/StarterPlayer/StarterPlayerScripts/QuickMathUI.client.lua` | `main` |
| `RaceQueueBootstrap.server.lua` | `src/ServerScriptService/RaceQueueBootstrap.server.lua` | `main` |
| `RaceQueueService.lua` | `src/ServerScriptService/RaceQueueService.lua` | `main` |
| `RaceQueueUI.client.lua` | `src/StarterPlayer/StarterPlayerScripts/RaceQueueUI.client.lua` | `archive/racequeueui-client` |
| `RaceQueueUI.client_1.lua` | `src/StarterPlayer/StarterPlayerScripts/RaceQueueUI.client.lua` | `main` |

Full hashes and exact duplicate relationships are recorded in [source-manifest.json](source-manifest.json).

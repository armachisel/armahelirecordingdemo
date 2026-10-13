# Arma Helicopter Recording Demo

A small, single-player Arma 3 mission demonstrating how to record a helicopter flight and replay its movement using a duplicate helicopter.

This is the companion mission for [Recording and Playing Back Helicopter Movement in SQF](https://armachisel.com/articles/recording-helicopter-movement-in-sqf/) on ArmaChisel. The article explains the recording format, coordinate systems, timing, interpolation, and the commented SQF example.

## Requirements

- Arma 3 **2.18 or later** (the script uses `setPhysicsCollisionFlag`).
- Altis and the standard MH-9 Hummingbird; no community mods are required by the supplied mission.
- Eden Editor, running the mission in **single-player**. The script deliberately exits in multiplayer.

## Open the mission

1. Download this repository using **Code → Download ZIP**, or clone it:

   ```sh
   git clone https://github.com/armachisel/armahelirecordingdemo.git
   ```

2. Copy the entire `testhelimission.Altis` folder into your active Arma profile's `missions` folder. Common locations are:

   - `Documents\Arma 3\missions\`
   - `Documents\Arma 3 - Other Profiles\<profile name>\missions\`

   If you are unsure which profile folder is in use, save a temporary scenario in Eden and choose **Scenario → Open Scenario Folder**. Its parent folder is the `missions` directory you need. Windows may place Documents under OneDrive.

3. In Eden, choose **Scenario → Open** and open `testhelimission` on Altis.
4. Choose **Play → Play in Singleplayer (SP)**.

The supplied mission already contains the helicopter named `myHeli`, a player pilot, and `init.sqf`. You do not need to create the script file or paste the article's code again.

## Record and replay

Use the mouse-wheel action menu:

1. Select **[REC] Start Telemetry** and fly a short route.
2. Select **[REC] Stop Telemetry** to keep that flight's recording.
3. Land and move clear of the recorded path. Choose a viewpoint where you can see the route; the demo does not move your camera.
4. Select **[PLAY] Play Replay** to spawn a duplicate and replay the flight.
5. Select **[PLAY] Stop Replay** to remove the duplicate early.

The controls are attached to the player and remain available inside or outside the helicopter. Starting a new recording replaces the previous recording. Starting another recording or replay removes the previous replay helicopter. At the end of playback, the duplicate holds its final pose for two simulation seconds before being removed.

## Files

- [`testhelimission.Altis/mission.sqm`](testhelimission.Altis/mission.sqm): Eden scenario, saved in Arma's binarized format. Edit it through Eden rather than a text editor.
- [`testhelimission.Altis/init.sqf`](testhelimission.Altis/init.sqf): commented recording, playback, cleanup, and action-menu code. Arma runs this when the mission starts.

After editing `init.sqf`, save it and restart the Eden preview. Do not repeatedly execute the whole file during a running preview, as that adds another set of menu actions.

## Scope and limitations

This is a teaching example, not the full LZ Trainer replay system. It records timestamps, ASL positions, nose/up vectors, and velocity, then blends saved states on each render frame. The sampling interval is a target, not a guaranteed rate.

- Recordings are kept in memory only; there is no export or persistence between sessions.
- No replay camera, seeking, replay-speed controls, or multiplayer support.
- Rotor preparation, recorded damage, and detailed sound/effect playback are not included.
- Collision handling is limited: roadway interactions and simulation effects can still interfere. Keep the original helicopter and other objects clear of the replay path.
- Use a fresh preview for each session; save/resume during an active replay is not supported.

## Adapting the code

Replace the example's `REC_` prefix with a distinctive prefix for your own project. Update every occurrence, including function names and quoted variable keys. Several adaptations retaining the same prefix can clash when combined in one mission.

See the [companion article](https://armachisel.com/articles/recording-helicopter-movement-in-sqf/) for the walkthrough and links to the relevant Bohemia documentation.

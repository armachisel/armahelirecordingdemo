/*
    Helicopter telemetry and playback teaching example.
    Eden single-player; Arma 3 2.18+; helicopter named myHeli.
    Paste the whole block into init.sqf, not into a unit's init field.

    Read section 3 to see a sample being saved.
    Read section 5c to see two samples being turned into movement.
*/

// 1. SETUP: this demonstration is for a player in single-player only.
// init.sqf can wait; the EachFrame handlers further down cannot.
if (!hasInterface || { isMultiplayer }) exitWith {};
waitUntil { !isNull player };

if (isNil "myHeli") exitWith { hint "Name the helicopter myHeli in Eden."; };
if (isNull myHeli || { !(myHeli isKindOf "Helicopter") }) exitWith {
    hint "myHeli must be a helicopter.";
};

// These REC_ variables are shared by the action buttons and handlers.
// Keep the prefix if adapting this, to avoid clashes with other scripts.
REC_frames = [];             // The list of saved samples for this flight.
REC_isRecording = false;     // Stops a second click starting another recorder.
REC_recordHandler = -1;      // -1 means no recording handler is registered.
REC_playbackHandler = -1;    // Same idea for the handler moving the ghost.
REC_ghostHeli = objNull;     // Reference to the duplicate, never the original.
REC_heliClass = "";          // The vehicle class to use when spawning the ghost.
REC_startTime = 0;           // Mission time when Start Telemetry was pressed.
REC_lastSampleTime = -1;     // Mission time of the most recent saved sample.
REC_sampleInterval = 0.05; // Target interval, not a guaranteed 20 Hz

// 2. CLEANUP: stop moving the ghost before deleting it.
// This is also called before starting a new recording or replay.
REC_fnc_stopPlayback = {
    if (REC_playbackHandler >= 0) then {
        removeMissionEventHandler ["EachFrame", REC_playbackHandler];
        REC_playbackHandler = -1;
    };
    if (!isNull REC_ghostHeli) then { deleteVehicle REC_ghostHeli; };
    REC_ghostHeli = objNull;
};

// 3. SAVE ONE SAMPLE: called repeatedly while recording.
REC_fnc_sample = {
    // true bypasses the interval check for the first/last sample.
    // It still cannot save a second sample at an identical time.
    params [["_force", false]];
    if (isNull myHeli || { !alive myHeli }) exitWith {};
    private _now = time;
    // A paused mission has not advanced. Do not save the same time twice:
    // playback divides by the time gap and that gap must be greater than 0.
    if (_now <= REC_lastSampleTime) exitWith {};
    // Usually wait until at least 0.05 simulation seconds have passed.
    // If a game frame runs late, keep its actual timestamp, not a made-up one.
    if (!_force && { (_now - REC_lastSampleTime) < REC_sampleInterval }) exitWith {};
    REC_lastSampleTime = _now;
    // pushBack appends one new sample to our list.
    // The numbers below are the array indexes used by playback's select.
    REC_frames pushBack [
        _now - REC_startTime, // 0: seconds since recording began.
        getPosASL myHeli,     // 1: position [east/west, north/south, ASL height].
        vectorDir myHeli,     // 2: direction of the nose.
        vectorUp myHeli,      // 3: direction of the roof (captures bank/pitch).
        velocity myHeli      // 4: movement velocity, in metres per second.
    ];
};

// 4. RECORDING CONTROLS: stop keeps the samples for the Play action.
REC_fnc_stopRecording = {
    if (!REC_isRecording) exitWith {};
    [true] call REC_fnc_sample; // Keep the end sample if time has advanced.
    REC_isRecording = false;
    if (REC_recordHandler >= 0) then {
        removeMissionEventHandler ["EachFrame", REC_recordHandler];
        REC_recordHandler = -1;
    };
    hint format ["Recording stopped: %1 samples.", count REC_frames];
};

REC_fnc_startRecording = {
    if (REC_isRecording) exitWith { hint "Already recording."; };
    if (isNull myHeli || { !alive myHeli } || { !local myHeli }) exitWith {
        hint "The original helicopter must be alive and local.";
    };
    // Stop any old ghost and replace the previous flight's recording.
    [] call REC_fnc_stopPlayback;
    REC_frames = [];
    REC_heliClass = typeOf myHeli;
    REC_startTime = time;
    // Put the previous sample time in the past so the first is accepted.
    REC_lastSampleTime = REC_startTime - 1;
    REC_isRecording = true;
    [true] call REC_fnc_sample;

    // EachFrame offers a chance to record on every render frame.
    // REC_fnc_sample decides whether enough time has passed to save one.
    REC_recordHandler = addMissionEventHandler ["EachFrame", {
        if (isNull myHeli || { !alive myHeli } || { !local myHeli }) exitWith {
            [] call REC_fnc_stopRecording;
        };
        [false] call REC_fnc_sample;
    }];
    hint "Recording telemetry.";
};

// 5. PLAYBACK: finish recording, then create and move the duplicate.
REC_fnc_startPlayback = {
    [] call REC_fnc_stopRecording;
    if (count REC_frames < 2) exitWith { hint "Record at least two samples first."; };

    // Copy the saved list for this playback, so replacing REC_frames later
    // does not switch the flight underneath an already-running replay.
    private _frames = +REC_frames;
    private _first = _frames select 0;
    private _firstTime = _first select 0;
    // Last sample time minus first sample time = length of the flight.
    private _duration = ((_frames select ((count _frames) - 1)) select 0) - _firstTime;
    if (_duration <= 0) exitWith { hint "Recording has no positive duration."; };

    [] call REC_fnc_stopPlayback;
    // 5a. Spawn the same helicopter type and apply its first saved state.
    // createVehicle needs an ATL position here, so convert our ASL value.
    // CAN_COLLIDE allows this spawn position; it does NOT disable collisions.
    private _ghost = createVehicle [
        REC_heliClass, ASLToATL (_first select 1), [], 0, "CAN_COLLIDE"
    ];
    if (isNull _ghost) exitWith { hint "Could not create replay helicopter."; };
    REC_ghostHeli = _ghost;
    _ghost allowDamage false; // Normal damage protection, not collision removal.
    _ghost setPhysicsCollisionFlag false; // Roadway interactions still remain.
    _ghost lock true; // Keep players from boarding the replay helicopter.
    _ghost setFuel 1;
    _ghost enableSimulation true; // Keep normal animation/simulation running.
    _ghost setPosASL (_first select 1);
    _ghost setVectorDirAndUp [_first select 2, _first select 3];
    _ghost setVelocity (_first select 4);
    _ghost engineOn true; // Does not instantly restore recorded rotor speed.
    // Store our bookmark on the ghost so the next frame can read it back.
    _ghost setVariable ["REC_frameIndex", 0];

    // Arma calls this block on EVERY render frame while replaying.
    REC_playbackHandler = addMissionEventHandler ["EachFrame", {
        // Read the values passed in the list at the end of this handler.
        // _playStart is mission time when Play Replay was pressed.
        _thisArgs params ["_ghost", "_frames", "_playStart", "_firstTime", "_duration"];
        // How far into the replay are we? 'max 0' prevents negative time.
        private _elapsed = (time - _playStart) max 0;

        // If something removed or destroyed the ghost, stop this handler.
        if (isNull _ghost || { !alive _ghost }) exitWith {
            removeMissionEventHandler ["EachFrame", _thisEventHandler];
            REC_playbackHandler = -1;
            if (!isNull _ghost) then { deleteVehicle _ghost; };
            REC_ghostHeli = objNull;
            hint "Replay ended.";
        };

        // 5b. Finish safely. A deletion deadline means we are holding
        // the last pose, not playing. Check the clock instead of using sleep.
        private _cleanupAt = _ghost getVariable ["REC_cleanupAt", -1];
        if (_cleanupAt >= 0) exitWith {
            if (time >= _cleanupAt) then {
                [] call REC_fnc_stopPlayback;
                hint "Replay ended.";
            };
        };

        if (_elapsed >= _duration) exitWith {
            // A slow frame may go past the end. Still show the exact final
            // pose, freeze it (including rotors), then wait two seconds.
            private _last = _frames select ((count _frames) - 1);
            _ghost setVelocity [0, 0, 0];
            _ghost enableSimulation false;
            _ghost setPosASL (_last select 1);
            _ghost setVectorDirAndUp [_last select 2, _last select 3];
            _ghost setVariable ["REC_cleanupAt", time + 2];
        };

        // 5c. THE MOVEMENT LOOP: find A and B, work out progress, blend.
        // Use the same time scale as the saved samples.
        private _playbackTime = _firstTime + _elapsed;
        private _index = _ghost getVariable ["REC_frameIndex", 0];
        // A must have a B after it. In a list of 10, the last pair is 8, 9.
        private _lastPair = (count _frames) - 2;
        // Has playback reached the next sample? Move the bookmark forward.
        // Keep going if a slow frame skipped over several sample times.
        while {
            _index < _lastPair &&
            { ((_frames select (_index + 1)) select 0) <= _playbackTime }
        } do {
            _index = _index + 1;
        };
        _ghost setVariable ["REC_frameIndex", _index];

        private _a = _frames select _index;       // Earlier saved sample.
        private _b = _frames select (_index + 1); // Next saved sample.
        // 'select 0' reads the timestamp INSIDE each sample.
        private _span = (_b select 0) - (_a select 0);
        // Time since A / time from A to B = progress through this gap.
        // Example: (12.34 - 12.30) / (12.35 - 12.30) = 0.8, or 80%.
        // 'max 0 min 1' keeps the result within the two samples.
        // The recorder's duplicate-time check means _span is never zero.
        private _alpha = ((_playbackTime - (_a select 0)) / _span) max 0 min 1;
        // Move AND orient the ghost for this render frame.
        // Use the same progress value for position, velocity, nose and roof.
        // This command does linear blending, not quaternion slerp.
        _ghost setVelocityTransformation [
            _a select 1, _b select 1, // Positions (ASL).
            _a select 4, _b select 4, // Velocities.
            _a select 2, _b select 2, // Nose directions.
            _a select 3, _b select 3, // Roof directions.
            _alpha                   // Fraction from A towards B.
        ];
        // On the next render frame, repeat with the new replay time.
        // These arguments carry our private values into the handler:
    }, [_ghost, _frames, time, _firstTime, _duration]];

    hint format ["Playing %1 seconds of telemetry.", round _duration];
};

// 6. ACTION-MENU BUTTONS: add the controls to the player only.
// Player actions remain available inside and outside the helicopter.
// Adding them to myHeli as well would show a second set of menu entries.
// Defining the functions above did not start them; these actions call them.
// isNil { ... } runs these short calls unscheduled, so a frame handler
// cannot interrupt halfway through changing the recording/playback state.
// We are using that execution behaviour, not the true/false result of isNil.
player addAction ["[REC] Start Telemetry", {
    isNil { [] call REC_fnc_startRecording; };
}];
player addAction ["[REC] Stop Telemetry", {
    isNil { [] call REC_fnc_stopRecording; };
}];
player addAction ["[PLAY] Play Replay", {
    isNil { [] call REC_fnc_startPlayback; };
}];
player addAction ["[PLAY] Stop Replay", {
    isNil { [] call REC_fnc_stopPlayback; };
}];
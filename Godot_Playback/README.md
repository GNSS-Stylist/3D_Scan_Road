# 3D_Scan_Road/Godot_Playback

Replayer of 3D-scan data.

## First Person Control

-**CTRL key** toggle between fly and edit mode.

-Use your **mouse** to look around when in fly mode and using the first person camera (F1).

- **WSAD**: go forward, backward, left, right
- **Q**: go down.
- **E**: go up.
- **T or mouse wheel up**: Increase first person's fly speed.
- **G or mouse wheel down**: Decrease first person's fly speed.
- **B**: Spawn a new 1 m3 box (cube).
- **Left mouse button** activate stick-type manipulator (not much of use here).
- **Right mouse button** activate plate-type manipulator (not much of use here).
- **F1**: Fly camera (world coordinates)
- **F2**: Fly camera (van coordinates)
- **F3**: Fly camera (car coordinates)
- **F4**: Camera following the van
- **F5**: Camera looking down on the lidar
- **F6**: Camera attached to the camera rig (on the roof of the car / walk camera)
- **F7**: Camera staying still (like in the beginning of the youtube-video)
- **F9**: Store current camera
- **F10**: Recall stored (with F9) camera
- **R**: Restart currently selected LOScript.
- **P**: Pause
- **H**: Hide "Show controls" / "Show info"-checkboxes.
- **Page down**: Jump 5s back in LOScript
- **Page up**: Jump 5s forward in LOScript
- **Keypad +**: Jump forward time defined in "Replay speed"-field (ms)
- **Keypad -**: Jump backward time defined in "Replay speed"-field (ms)
- **F12**: Full screen toggle

I'd recommend to just try everything out if interested. There's nothing to break (I hope).

# Credits

The original flying code is from Jeremy Bullock's youtube tutorial series on first person control.

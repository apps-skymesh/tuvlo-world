# Run and test

Godot **4.7.2-stable** is the engine version for this project.

## Mac

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) in `/Applications`.
2. Run `scripts/run-mac.sh`, or open `Godot/project.godot` in Godot and press Play.

Saves go to Godot's user folder (`~/Library/Application Support/Godot/app_userdata/Tuvlo World/tuvlo-world-save.json`). Delete that file to start over.

## iPhone and iPad

1. Run `sh scripts/export-ios.sh`. The first time, it downloads and installs the Godot 4.7.2 export templates (about 1 GB). It then writes an Xcode project into `build/ios/` and opens it.
2. In Xcode, plug in your iPhone or iPad, pick it as the run target and press Run. Signing uses Team `F36G3M2Y7Y` (the same team as Tuvlo) with automatic signing. The first run on a device needs **Settings › General › VPN & Device Management** to trust the developer.

The bundle ID `com.skymesh.tuvloworld` is provisional. The same preset targets both iPhone and iPad (device family 2) on iOS/iPadOS 18.0 and later. The game is landscape-only on both.

## Tests

`scripts/test.sh` runs the headless rules tests (`Godot/tests/game_rules_tests.gd`), which cover:

- the farm, mill and oven timers;
- fixed spots and level gates;
- purchases and market sales through the host;
- a failed save changing nothing;
- duplicate and conflicting records during replay;
- the renderer accepting every snapshot.

`tests/solo_capture.gd` plays a few steps and saves screenshots:

```sh
godot --path Godot -s res://tests/solo_capture.gd -- /tmp/captures
```

Tests are excluded from exports.

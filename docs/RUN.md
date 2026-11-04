# Run and test

Godot **4.7.2-stable** is the engine version for this project.

## Mac

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) in `/Applications`.
2. Run `scripts/run-mac.sh`, or open `Godot/project.godot` in Godot and press Play.

Saves go to Godot's user folder (`~/Library/Application Support/Godot/app_userdata/Tuvlo World/tuvlo-world-save.json`). Delete that file to start over.

## iPhone and iPad

1. In Godot, install the 4.7.2 export templates (**Editor › Manage Export Templates**).
2. Open **Project › Export › iOS** and set your **App Store Team ID**. The bundle ID is `com.skymesh.tuvloworld`, which is provisional.
3. Export. The preset writes an Xcode project into `build/ios/` because `export_project_only` is on.
4. Open that project in Xcode, pick your iPhone or iPad and press Run.

The same preset targets both iPhone and iPad (device family 2) on iOS/iPadOS 18.0 and later. The game is landscape-only on both.

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

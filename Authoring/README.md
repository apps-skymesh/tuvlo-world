# Original cottage authoring

`build_cottage.py` is the reproducible source for `../Godot/assets/cottage/cozy_cottage.glb`. It uses Blender 4.5.2 LTS, deterministic seed 72531 and original modeled geometry/materials. No downloaded models, textures, accounts or external service are used. Authoring files stay outside the shipped Godot project.

Run from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python WorldRuntime/Authoring/build_cottage.py
```

The current GLB is 2,676,944 bytes with 92,300 triangles and 21 shared materials. This is an asset inventory, not a performance result. Props are consolidated by material; roof material names retain treehouse palette support. Closed gables, rounded forms, recessed openings and fitted details are authored in geometry. All placement/ownership identifiers stay in Tuvlo's existing data, outside this asset.

After changing art, regenerate the web and native packs using the existing preparation scripts; do not run the automated checks after every edit. Use `scripts/world-mac.py --play --cottage --camera home` with `TUVLO_GODOT_BIN` set for manual review. Tests, iOS/WebGL parity, physical performance and final visual approval remain deferred.

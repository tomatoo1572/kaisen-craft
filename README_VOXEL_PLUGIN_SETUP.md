# KaizenCraft voxel plugin setup

This project has been prepared for Zylann Voxel Tools.

Recommended plugin:
- Official `GodotVoxelExtension.zip` release package from `Zylann/godot_voxel`
- Use the `Voxel Tools 1.6 GDExtension for Godot 4.5+` package

Why this package:
- Works with official Godot 4.6
- Structured like a plugin
- Intended to be extracted at the root of the project

Important warning:
- Do not combine the GDExtension package with a Godot editor build that already includes the voxel module.

After install, verify these files exist:
- `addons/zylann.voxel/voxel.gdextension`
- `addons/zylann.voxel/plugin.cfg`
- `addons/zylann.voxel/bin/`

Suggested first migration path for KaizenCraft:
1. Keep your current project as a backup.
2. Install the voxel plugin into this prepared copy.
3. Create a separate voxel test scene first.
4. Validate `VoxelTerrain`, `VoxelMesherBlocky`, `VoxelBlockyLibrary`, and `VoxelViewer`.
5. Only after that, replace the current custom chunk renderer incrementally.

Suggested next implementation order:
1. Blocky terrain test scene
2. Player spawn / collision on voxel terrain
3. Block place / break integration
4. Inventory and registry integration with voxel block IDs
5. Save/load and streaming
6. Terrain biomes / world shaping pass

If you upload the official plugin zip into ChatGPT, the project can be repacked with the plugin fully merged.

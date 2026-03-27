KaizenCraft project with Zylann Voxel Tools GDExtension merged in.

What was added:
- addons/zylann.voxel/

How to open:
1. Open this project in official Godot 4.6.
2. If Godot prompts about loading the GDExtension, allow it.
3. Reopen the project once if voxel classes do not appear immediately.

Important:
- Use the normal official Godot editor, not a custom Godot build that already has the voxel module built in.
- Do not mix the module version and the GDExtension version in the same project/editor build.

Quick sanity check:
- Create a node and confirm classes like VoxelTerrain, VoxelLodTerrain, or VoxelViewer are available.

Next recommended step:
- Build a clean voxel test scene first before replacing the current terrain system.

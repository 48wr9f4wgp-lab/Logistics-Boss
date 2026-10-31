# FORGE visual assets — v0.9 / 2026-10-31

Title-local assets for the playable Canvas prototype. These are development graphics, not a production art approval.

- `machine-atlas.png`: generated with the built-in ImageGen tool. Four isolated rendered industrial machines on transparent RGBA: amber bandsaw, teal drill press, olive lathe, inspection bench. 1254×1254. The actual output is not an equal-cell atlas: `renderer.mjs` uses individually measured source crops and a small boundary clip between the cutter and lathe.
- `worker-atlas.png`: built-in ImageGen generated four adult navy-coverall worker poses on transparent RGBA, 1254×1254. Renderer uses tight pose crops, actual simulation route coordinates, current work state and a small walking/working motion. It does not advance the simulation or create fake jobs.

Prompt summary: orthographic isometric premium miniature game art, warm upper-left light, restrained paint wear, readable mechanical silhouettes, transparent background, no text or environment. Workers use navy coveralls, boots and caps, adult proportions; standing, carrying and operating poses.

TARGET: conversation concept, Library file `libfile_5096c9470d308191941431528267f2b4` (町工場FORGEの鉄工所シミュレーション.png). The approved direction is a tactile Japanese machine workshop, olive/teal machines, warm windows and navy workers. This implementation simplifies the target into movable 2D sprites on a projected floor. It does not reproduce its dense perspective room, full 3D lighting, continuous mechanical articulation or rendered-human animation.

All generated imagery is bundled; gameplay requires no image-generation service or external image host. Generated images have no third-party source artwork. Rendering fallback keeps machine selection and game logic available if a PNG is unavailable. `model.mjs`, save schema and prices are not modified by these assets.

Crop order in renderer: cut (65,28,570,660), drill (775,25,375,678), lathe (35,672,660,568), inspect (730,700,515,540). Units are source pixels. Source images remain unmodified outputs; runtime clip trims neighboring atlas silhouettes.

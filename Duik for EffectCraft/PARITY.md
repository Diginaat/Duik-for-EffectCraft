# Duik 17.1.21 parity tracker

Scope: recreate documented Duik workflows in the EffectCraft plug-in, not run the After Effects plug-in unchanged. A workflow counts as covered when exercised on EffectCraft 0.24.1. For rigging and animation, verify actual pose or property changes and persistence, not just panel controls. Existing After Effects project and `.ffx` migration are separate compatibility work.

| Family | Working coverage | Remaining milestones |
| --- | --- | --- |
| Kinematics | One-bone aim and keyframeable FK; planar two-bone IK/FK with two-way pose matching, bend flip, and optional uniform stretch; three-bone IK with lead angle and tail bend; Bézier IK and rotation-driven Bézier FK; static artwork to FK chain and overlapping FK | One-bone and stretched pose matching, three-bone FK switching, Bézier Auto-Curve |
| Bones and autorig | Bone nulls at artwork pivots; bind artwork without shifting its pose; arm and leg IK/FK templates; spine FK template; tail and hair FK templates with overlap | Wing, fin, snake, and custom templates; full-character autorig; envelopes and noodles; bone editing |
| Controllers | Null or shape-layer controllers (circle, square, cross, arrows); zero parents; shared master for two-bone IK/FK rigs | Controller tagging and selection by type, controller extraction across compositions |
| Constraints | Aim and position with rest offsets; single-driver 2D parent constraint with keyframeable weight; 2D mask following with tangent orientation; connector (transform or effect driver onto keyframe range); lock; reset transform; align; mask and shape path vertex pins with tangent handles | Multiple parents and pose-preserving switches, scale inheritance, shape-path following, puppet pins (not exposed by EffectCraft scripting), parent across compositions |
| Animation | Temporal interpolation presets with ease influence; straight motion path and roving; tween; freeze pose; snap, sync, and clean keys; layer sequencing; exposure; copy and paste animation | Kleaner-style anticipation and follow-through, split keys, cel animation, NLA, animation library |
| Automation | Wiggle; random; swink; spring; cycle loop; horizontal and curved-ground wheel roll; effector; motion trail; move away; bake, toggle, and remove expressions | Walk and run cycles, effector maps, randomize layer and key times, time remap (not scriptable in EffectCraft 0.24.1), paint rig |
| Layer and utility tools | Native solid and adjustment layers; reference-preserving rename with find/replace, prefix, and suffix; composition notes | Shape-based solids and adjustment layers, side/location layer attributes, expression editor and script library |
| Camera and OCO | 2D parallax camera with per-layer depth, rotation, and zoom; 3D camera rig with root, body, and target nulls | Camera framing guides, Z-scale link, OCO meta-rig workflows |

Next milestone: multi-parent constraint with pose-preserving switches.

## EffectCraft 0.24.1 limits found while porting

- Path expressions fail silently when they call `points()`, `inTangents()`, `outTangents()`, or `isClosed()` on their own path; pins bake rest geometry into the expression instead.
- `.property(...)` chains in expressions return nothing and report no `expressionError`; generated expressions use `effect(name)(index)` and named transform accessors.
- Expression errors on path properties are not reported through `expressionError`, so path tools are verified by reading evaluated values.
- Puppet effect pins and layer time remapping are not available to scripts.

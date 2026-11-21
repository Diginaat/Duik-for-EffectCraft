# Duik tools for EffectCraft

This EffectCraft plug-in bundle implements selected Duik-style workflows. It uses EffectCraft layers and expressions, not After Effects, Duik's runtime, or `.ffx` presets. It is not a complete Duik port or a converter for existing Duik rigs.

**New to the panel?** Open the [HTML user guide](docs/index.html) in your browser. It works offline and includes a screenshot install walkthrough, four step-by-step guides (IK arm, overlapping tail, connector fade, parallax camera), and a tab-by-tab reference.

## Install

In EffectCraft 0.24.1, use **Effect → Install Effect Plug-in Bundle (Folder)…** and choose the `plug-in` folder. Open **Window → Duik for EffectCraft.jsx**. The bundle installs one dockable panel with **Rigging**, **Armature**, **Constraints**, **Animation**, **Automation**, **Layers**, and **Camera** sections. Switch sections with the icon bar at the top. The current section's name shows beside the icons, and hovering an icon shows its name. The sections are called tabs below. No `.wasm` module is needed: the pixel-effect ABI does not edit project layers.

## Rigging tab

**Arm and leg templates:** Choose **Arm** or **Leg**, then click **Create Template**. The panel creates two bone nulls and a target null with the two-bone IK/FK controls already wired. At the setup pose, place artwork over the bones and use **Armature → Bind Artwork to Bone** for each bone. Animate the wrist or ankle target.

**Spine, tail, and hair templates:** Choose **Spine** (hips to head, 5 bones), **Tail** (5 bones), or **Hair** (4 bones), then click **Create Template**. Each creates a parented FK chain of bone nulls; animate bone Rotation. Tail and hair roots get **Delay Frames** and **Overlap Amount**, like **Build Overlapping FK**. Templates create one body part at a time; they do not analyze artwork or assemble a full character.

**Rig Master:** Select the target nulls of one or more unparented two-bone IK/FK rigs that support pose matching, then click **Group IK/FK Rigs Under Master**. Animate the new master null's Position or Rotation to move those rigs together. Grouping preserves existing local keyframes and bound artwork. Keep all three layers of each grouped rig under the same parent so IK and pose matching use a shared coordinate space.

**One bone:** Place one unlocked, unparented 2D limb above its target null. Select both, then click **Build One-Bone IK/FK** in the rest pose. Animate the target's **Position** to aim the limb with its original angular offset. Keyframe **Use FK** on the target to switch to **FK Rotation**, an offset from rest rotation. This rig rotates the limb without stretching it; automatic pose matching remains two-bone only.

**Three bones:** Place three unlocked, unparented 2D limbs in root-to-tip timeline order above a target null. In the rest pose, set each limb's anchor at its joint and place the target at the last limb's tip. Select all four layers, then click **Build Three-Bone IK**. Animate target **Position**. Keyframe **Lead Angle** to bias the first joint and **Flip Tail Bend** to reverse the trailing bend. The rig keeps fixed lengths and clamps targets outside its near and far reach. Three-bone rigs are IK-only: no FK switching or stretch.

**Bézier IK:** Place 2–16 unlocked, unparented 2D limb layers in root-to-tip timeline order, followed by three nulls: start handle, end handle, tip. Set each limb's anchor at its joint. Select the whole chain and all three nulls, then click **Build Bézier IK**. Animate the handle and tip Positions to shape the curve; animate the first limb's Position to move the root. The builder distributes joints by approximate curve length using the setup segment lengths as weights. Each segment rotates and scales uniformly to connect its two joints; individual artwork layers do not bend. Driven Position, Rotation, and Scale must be unanimated at setup.

**Bézier FK:** Same chain setup, but use four nulls in timeline order: root, start handle, end handle, tip. Place the root null at the desired pivot and click **Build Bézier FK**. Root Position and Rotation move the whole curve; tip Rotation turns the end tangent without shifting the endpoint. Handle and tip Positions still shape the curve in the setup coordinate frame. The nulls stay independent: root Rotation changes the rig, not the visible positions of the other nulls. No IK/FK switching or Auto-Curve control on these rigs.

**Two bones:**

1. In one composition, use two unparented 2D art layers and one unparented 2D null. Put them in this relative timeline order: upper limb, lower limb, target null. Set the upper layer's anchor at the shoulder and the lower layer's anchor at the elbow. Move the target null's Position to the lower limb's tip. Build in the intended rest pose; the elbow's starting side sets the bend direction.
2. Select all three layers, then click **Build Two-Bone IK**. Animate the target null's **Position**. Unreachable targets clamp to the rig's reach. The upper layer's Position can be keyframed to move the shoulder.

For a switchable rig, choose **Build Two-Bone IK/FK** instead. In the target null's **Effect Controls**, **Use FK** off means animate target **Position**; on means animate **FK Shoulder** and **FK Elbow** as joint offsets from the rest pose. For a matched switch, select the original three layers and click **Match Pose and Switch IK/FK** at the desired frame. This keys the destination controls and switches modes in one undo step. FK → IK also sets **Flip IK Bend** when needed. It cannot match a fully folded pose with the tip at the shoulder. Rigs built before pose matching was introduced still work but cannot use automatic matching.

New switchable rigs have a keyframeable **Stretch IK** checkbox, off by default. When on, both limbs scale uniformly past rest reach so the tip tracks the target. In-reach poses and FK keep their rest scale. Bring the target back within rest reach before matching a stretched pose to FK. Existing rigs are not modified; build a new rig to get stretch.

Keep layer names unique; don't rename the upper layer, target null, or generated controls unless you update their expression references. Lower Position and both Rotations must not already be driven; switchable rigs also need unanimated Scale on both limb layers. Changes to artwork, anchors, or base scales do not recalculate limb lengths. No 3D or autorig. The generated expressions are saved in `.ecproj`.

## Armature tab

- **Build FK Armature from Artwork** creates a chain of bone nulls at the pivots of two or more selected 2D layers and parents each layer to its bone without moving the art. Order the selection in the timeline from root to tip. Layers must be unparented with static transforms. Animate the bone nulls' Rotation.
- **Build Overlapping FK** uses the same setup for 2–16 layers. Animate root bone Rotation. On that bone, **Delay Frames** sets lag per joint and **Overlap Amount** blends from ordinary FK (0) to full lag (100). Child bone Rotation remains available for local adjustments.
- **Bind Artwork to Bone** binds additional unparented, static artwork to an existing bone null, preserving its current pose. Put the null above the artwork in the timeline and select both.
- **Aim at Driver (Keep Offset)** drives follower Rotation toward the top selected layer while preserving the initial angular offset. **Follow Driver Position** drives follower Position while preserving its initial positional offset. Use unparented 2D layers, a uniquely named driver, and followers without keys or expressions on the driven property. Animate the driver's Position. Keep the driver name unchanged or update its expression references.
- **Add Weighted Parent Constraint** uses the top selected unparented 2D layer as driver. Select it and one or more unparented followers at the setup frame. Keyframe each follower's **Parent Weight** from 0 (original animation) to 100 (follow driver Position and Rotation relative to setup). Existing keys and hierarchy stay intact. This supports one driver, not scale inheritance or automatic pose matching when switching weight.
- **Follow Selected Mask Path:** Put the 2D mask layer above its followers. Select the layers and exactly one **Mask Path** property on the mask layer, then click the button. Keyframe **Path Progress** from 0 to 100 on each follower; enable **Orient to Path** to add the tangent angle to its Rotation. Animated masks and layer transforms are supported. Followers need unparented, unanimated Position. Shape-layer paths are not supported by this tool.

## Constraints tab

- **Connector:** Select one driver property and click **Set Driver**. Drivers can be transform properties (Position, X/Y Position, Rotation, Scale, Opacity, Anchor Point) or effect controls such as sliders and angles; vector drivers use the chosen axis. Then select properties with two or more keys and click **Connect Keys to Driver**. Driver values from **From** to **To** play the keyed animation from its first key to its last; values outside that range clamp.
- **Effector:** Select properties with two or more keys and click **Effector**. A new **Effector** null drives them by distance to each property's layer anchor: inside **Inner Radius** they reach their last key, beyond **Outer Radius** they stay at their first key.
- **Lock** replaces each selected property with an expression holding its current value.
- **Reset Transform** sets Rotation to 0 and Scale to 100% on selected layers, and Position to 0 when parented (a zero parent's origin). Keyed properties get a key at the current time.
- **Align to Top** moves the selected layers' Position to the top selected layer's anchor in composition space, converting into each layer's parent space.
- **Pin Path Vertices:** Select one unanimated **Mask Path** or shape-layer **Path**, then click the button. Each vertex gets a pin null; nonzero tangents get **In** and **Out** handle nulls parented to their pin. Animate the pins to deform the path; rotating a pin turns its handles. Shape groups above the path must have default transforms. Puppet pins are not supported: EffectCraft does not expose puppet pin properties to scripts.

## Animation tab

Interpolation tools need selected keyframes. Other tools use the selected keyed properties or, with none selected, every animated property of the selected layers.

- **Linear**, **Ease In**, **Ease Out**, **Easy Ease**, **Hold**, and **Smooth** set temporal interpolation on selected keys. **Ease %** sets the influence.
- **Straight Path** removes spatial tangents on selected Position keys; **Rove** makes inner spatial keys rove in time.
- **Tween** adds a key at the current time between the surrounding keys at **Tween %**. **Freeze Pose** copies the previous key to the current time.
- **Snap Keys** moves selected keys (or all keys) onto whole frames. **Sync Keys** moves each property's selected keys so its first selected key lands on the current time. **Clean Keys** removes keys that repeat both neighbors. Moved keys keep their values, eases, and interpolation.
- **Sequence Layers** offsets the selected layers by **Frames**, in timeline order. **Exposure** adds an expression that holds each pose for **Frames** frames.
- **Copy Anim** stores animation relative to the current time; **Paste Anim** applies it to matching properties of the selected layers at the current time. The clipboard lasts while the panel is open.

## Automation tab

Select numeric properties in the timeline, not property groups. None of these tools overwrite existing expressions.

- **Wiggle** uses the frequency and amplitude fields as constants.
- **Random** holds a new random offset per dimension at each tick. **Swink** swings around the value, or blinks between two values when **Swink Blink** is on. **Spring** adds a damped overshoot after each key, scaled by the speed entering that key. Their controls, such as **Spring Amplitude**, **Spring Frequency**, and **Spring Decay**, are added once per layer and shared by that layer's properties.
- **Cycle Loop** needs two or more keys and repeats them before the first key and after the last key.
- **Roll Wheel:** Select one unparented 2D wheel layer with its anchor at the wheel center. Set the wheel radius in comp pixels, move to the setup frame, and click the button. By default horizontal travel drives Rotation. With **Wheel follows curved motion** on, the expression adds up path length frame by frame, signed by horizontal direction, so wheels roll over hills; long compositions evaluate more slowly.
- **Motion Trail** adds a shape layer that draws each selected layer's recent path; **Trail Frames** sets its length (2–240).
- **Move Away** adds a **Move Away** slider that pushes parented layers along the line from their parent's anchor point.
- **Bake** samples expressions once per frame across each layer's time span, then replaces them with linear keys, dropping keys on straight runs. **Toggle** enables or disables expressions; **Remove** deletes them. With no expression property selected, these act on every expression of the selected layers.

## Layers tab

- **Add Controllers** creates one controller per selected, unparented 2D layer, aligned to its current Position, or one at the composition center. **Controller shape** picks a native null or a shape-layer **Circle**, **Square**, **Cross**, or **Arrows** icon.
- **Add Zero Parents** creates a null at each selected layer's pivot and parents the art without moving it, yielding zero local Position. Requires static transforms on unlocked, unparented 2D layers.
- **Add Comp-Sized Solid** and **Add Adjustment Layer** create native EffectCraft layers.
- **Rename** applies **Find**/**Replace**, **Prefix**, and **Suffix** to the selected layers and rejects duplicate names. It also rewrites `layer("…")` references and Duik rig metadata in the composition, so existing rigs keep working.
- **Save Notes** stores the text box in the composition's comment; **Load Notes** reads it back.

## Camera tab

- **Add 2D Camera:** Select unparented 2D layers. A **2D Camera** null drives their Position, Rotation, and Scale around the composition center. Animate its Position, Rotation, and **Zoom**; each layer's **Camera Depth** sets how strongly it follows (100 full, 50 half, 0 fixed).
- **Rig 3D Camera:** Select an unparented camera with static Position and Point of Interest, or nothing to add one. **Camera Root** moves or orbits the rig; **Camera Body** places the camera and **Camera Target** aims it.

## Port status

See the [parity tracker](PARITY.md) for verified coverage and remaining gaps. Existing Duik projects and presets are not imported.

## Verify

Run from this folder on Windows. Rebuild after editing files under `src/`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Bundle.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -IkFk
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -PoseMatch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -Stretch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -OneBone
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -ThreeBone
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -Bezier
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Rigging.ps1 -BezierFk
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-AdditionalTools.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Tools.ps1
```

The headless test loads the bundle as a palette, exercises the button with and without a valid selection, saves a temporary project, reopens it, and checks elbow alignment, animated tracking, and reach clamping. `-IkFk` checks manual switches; `-PoseMatch` checks matched switches in both directions, including an opposite bend; `-Stretch` checks scaled reach and return to clamping; `-OneBone` checks aim offset, coincident pivots, and keyframed FK rotation and mode switching.

`Test-Tools.ps1` runs the cases in `Test-Tools.Cases.ps1` for the Constraints, Animation, Automation, Layers, and Camera tools and the body-part templates; `-Only 'Path*'` runs matching cases. Each case drives the panel, saves, and checks the reopened project.

The desktop test installs the unified panel through the bundle installer if missing, verifies its seven section icons, then exercises layer creation, animated expressions, FK motion, artwork binding, and aim and position constraints in disposable compositions. If testing a rebuilt bundle, reinstall the panel first; EffectCraft won't overwrite an existing install.

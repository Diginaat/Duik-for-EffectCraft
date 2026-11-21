# Duik for EffectCraft

**[Download](https://github.com/Diginaat/Duik-for-EffectCraft/releases/latest)** · **[User guide](https://diginaat.github.io/Duik-for-EffectCraft/)**

Rigging and animation tools for EffectCraft, based on the workflows of [Duik](https://github.com/RxLaboratory/Duik) for After Effects.

One dockable panel with seven sections: **Rigging**, **Armature**, **Constraints**, **Animation**, **Automation**, **Layers**, and **Camera**. Build IK arms and legs, follow-through tails, controllers, 2D parallax cameras, and expression-driven animation from native EffectCraft layers.

![The Duik for EffectCraft panel docked in EffectCraft](Duik%20for%20EffectCraft/docs/images/panel-docked.png)

## Download

Get the latest zip from **[Releases](https://github.com/Diginaat/Duik-for-EffectCraft/releases/latest)**.

## Install

1. Unzip the download.
2. In EffectCraft 0.24.1 or later, choose **Effect → Install Effect Plug-in Bundle (Folder)…**.
3. Select the `plug-in` folder and click **Select Folder**.
4. Open **Window → Duik for EffectCraft.jsx**.

## Learn

**[Read the user guide online](https://diginaat.github.io/Duik-for-EffectCraft/)**, or open [`Duik for EffectCraft/docs/index.html`](Duik%20for%20EffectCraft/docs/index.html) offline. It includes:

- a screenshot walkthrough of the install,
- four step-by-step guides: an IK arm, an overlapping tail, a slider-driven fade, and a parallax camera,
- a tab-by-tab reference and troubleshooting.

| Rig an arm with IK | Overlapping tail | Parallax camera |
| --- | --- | --- |
| ![IK arm](Duik%20for%20EffectCraft/docs/images/arm-5-reach.png) | ![Fox tail](Duik%20for%20EffectCraft/docs/images/tail-overlap.png) | ![Parallax](Duik%20for%20EffectCraft/docs/images/camera-2d.png) |

## Repository layout

- [`Duik for EffectCraft/`](Duik%20for%20EffectCraft/): the plug-in, its sources, build and test scripts, and the user guide. See its [README](Duik%20for%20EffectCraft/README.md) for developer notes and the [parity tracker](Duik%20for%20EffectCraft/PARITY.md) for coverage.
- Everything else: the original Duik 17.1.21 source for After Effects. See [README-Duik.md](README-Duik.md).

## Scope

This recreates selected Duik workflows inside EffectCraft. It is not a full Duik port. It doesn't run After Effects, import existing Duik rigs, or use `.ffx` presets.

## License

[GNU GPL v3](LICENSE.md), like Duik. Duik is by [RxLaboratory](https://rxlaboratory.org).

# SVASF — Sea Vessels And Space Freight

**SVASF** stands for **S**ea **V**essels **A**nd **S**pace **F**reight: ships on the seas of Nauvis and the other
planets, and freight carried through space. (The name came first; the meaning was found for it later.)

This repository keeps two [Factorio](https://factorio.com) mods alive on **Factorio 2.1**, with optional
**Space Age** support:

| Folder | Mod | What it is |
|---|---|---|
| [`FreightForwarding/`](FreightForwarding/) | **Freight Forwarding 2.0.0** | A small overhaul about long-distance logistics: island terrain, ships, containers and resources far away. Ported from Factorio 1.1 (version 1.9.0) and extended for Space Age. |
| [`IntermodalContainers-continued/`](IntermodalContainers-continued/) | **Intermodal Containers (continued) 2.1.5** | Load items into containers for dense transport. A continuation of Intermodal Containers for Factorio 2.1; required by Freight Forwarding. |

Both mods are published on the mod portal under the names `FreightForwarding-continued` and
`IntermodalContainers-continued`, so they don't clash with the original mods.

## What Freight Forwarding gives you

### Classic mode
A startup setting that keeps Freight Forwarding exactly as it was in 1.x, even when Space Age is installed:
island-based Nauvis, lead at the edge of the starting island, offshore oil, dredging nodules from seamounts,
titanium from other islands, titansteel smelted in faraway lava pools, rocket silos only in natural craters.

### Extended mode (default)
Everything from classic mode, plus:

* **Space Age progression** — tiered rocket silos (light 500 kg, normal, heavy 2 t), planet supply chains (cobalt and
  titansteel on Vulcanus, battery packs on Fulgora, refrigerated containers on Gleba, lithium battery packs and
  freight science on Aquilo), ships and trains for each planet (lava barges Mk1/Mk2, swamp barges, icebreakers,
  fast and heavy cargo ships).
* **Containers** — container tiers (refrigerated, light, cryo), tank containers for fluids (and cryo tanks whose
  contents boil off), container wear (damaged containers can be repaired or recycled), spoiled reefers.
* **Sea infrastructure** — port cranes, offshore wind turbines, tidal generators, cable terminals, subsea power
  cables, subsea pipelines (with big duct landings from Fluid Must Flow), dredgers Mk2/Mk3 with a dredger planner,
  a dry dock that repairs and upgrades ships in place.
* **The Long Caravan** — Space Age's endgame becomes interstellar freight contracts: choose contracts, meet
  deadlines, build reputation, unlock caravan blueprints, catch the Great Caravan. A caravan exchange trades
  containers of basic goods at drifting prices.
* **Delivery permits** — some key technologies first need a container delivered to a research post on a planet.
* **Logistics tools** — cargo sensor (unpacked contents of a stopped train or ship as signals), spoilage sensor,
  routes panel (every train and ship at a glance), freight statistics, cargo insurance.
* **Maps** — Freight Forwarding island terrain and an **Archipelago** map preset and scenario with goals and rewards.
* **Compatibility** — Krastorio 2 and K2 Spaced Out, Mining Space Industries II, planet mods (Cerys, Maraxsis,
  Muluna, Moshine), Alien Biomes, LTN, Cybersyn, AAI Industry and more: see
  [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md).
* **Languages** — English, Russian, Ukrainian, French, German and Japanese.

## Installing

Build the zips (see below) or take them from the mod portal once they are published, and put them in your
Factorio `mods` folder:

* `IntermodalContainers-continued_2.1.5.zip`
* `FreightForwarding-continued_2.0.0.zip`

Freight Forwarding also needs these mods from the mod portal: Cargo Ships, BZ Lead, BZ Titanium, Fluid Must Flow,
Robot256Lib, Spidertron Enhancements, Spidertron Patrols and flib. Space Age is optional.

Start a new game with the **Freight Forwarding Default** map preset (or **Freight Forwarding - Archipelago**).

## Building

```
python3 tools/build-portal.py            # dist/FreightForwarding-continued_<version>.zip and IntermodalContainers-continued_<version>.zip
python3 tools/build-portal.py --original # dist/FreightForwarding_<version>.zip, with the original mod name
```

## Testing

* [`tools/ff-selftest/`](tools/ff-selftest/) — a test mod: on a throwaway map it builds test setups and writes
  `FFSELFTEST PASS/FAIL` lines to `factorio-current.log`.
* [`tools/mock-data-stage/`](tools/mock-data-stage/) — checks the data stage and noise expressions without Factorio.
* [`docs/LOCAL_TESTING.md`](docs/LOCAL_TESTING.md) — checklist for things that can only be seen in the game client.
* [`docs/LOCAL_SESSION.md`](docs/LOCAL_SESSION.md) — automated checks on your own PC, with the list of mods to download.

## Documentation

* [`docs/PORT_2.1.md`](docs/PORT_2.1.md) — what changed in the port to Factorio 2.1 and how it was checked.
* [`docs/SPACE_AGE_IDEAS.md`](docs/SPACE_AGE_IDEAS.md) — design notes for the Space Age features.
* [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) — other mods: what was checked and how they work together.
* [`docs/MOD_PORTAL.md`](docs/MOD_PORTAL.md) — publishing on the mod portal.
* [`FreightForwarding/changelog.txt`](FreightForwarding/changelog.txt) — full changelog.

## Authors

* **Freight Forwarding** — originally by Xorimuth, with contributions from RedRafe and the Freight Forwarding
  community; continued for Factorio 2.1 by GemMaxweLlX.
* **Intermodal Containers** — originally by Xorimuth and RedRafe, developed from Deadlock's Crating Machine by
  Deadlock989; continued for Factorio 2.1 by GemMaxweLlX.
* Graphics and other assets from other authors are credited in [`NOTICE.md`](NOTICE.md).

## License

Everything in this repository is free software under the **GNU General Public License, version 3** — see
[`LICENSE`](LICENSE). Each mod also carries its own copy of the licence, as required when it is distributed on its
own: [`FreightForwarding/LICENCE.txt`](FreightForwarding/LICENCE.txt) and
[`IntermodalContainers-continued/license.txt`](IntermodalContainers-continued/license.txt).

Third-party assets, dependencies and trademarks are listed in [`NOTICE.md`](NOTICE.md).

Factorio is a trademark of Wube Software. This project is not affiliated with or endorsed by Wube Software.

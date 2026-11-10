# Notices, licences and credits

## Code

| Part | Authors | Licence |
|---|---|---|
| `FreightForwarding/` | Xorimuth (original), GemMaxweLlX (continuation) | GPL-3.0 — `FreightForwarding/LICENCE.txt` |
| `IntermodalContainers-continued/` | Deadlock989 (Deadlock's Crating Machine), Xorimuth and RedRafe (Intermodal Containers), GemMaxweLlX (continuation) | GPL-3.0-or-later — `IntermodalContainers-continued/license.txt` |
| `tools/`, `docs/` and everything else | GemMaxweLlX | GPL-3.0 — `LICENSE` |

The island map generation (`FreightForwarding/prototypes/map-gen.lua`) is based on
[Island Start](https://mods.factorio.com/mod/IslandStart) by Yehn, itself based on Factorio 1.1's elevation.

Modified versions of these mods must stay under the GPL-3, keep these licence files, credit the original authors
and make their source code available.

## Graphics and sounds

These assets came with the original Freight Forwarding and are credited by its author as follows. They remain the
work of their authors; ask them before reusing them outside Freight Forwarding.

* Galdoc — lava pool and rocket frame item graphics.
* Stringweasel — seismic scanner graphics (from [Biter Power](https://mods.factorio.com/mod/biter-power)).
* FragJacker — battery charging/discharging station graphics (from [SE Space Trains](https://mods.factorio.com/mod/se-space-trains)).
* PantherX and Kirazy — dredging platform tile graphics (from [Dectorio](https://mods.factorio.com/mod/Dectorio)).
* PreLeyZero — tailings water icon (from [Exotic Industries](https://mods.factorio.com/mod/exotic-industries)) and
  offshore storage tank graphics (from [Exotic Industries: Tanks](https://mods.factorio.com/mod/exotic-industries-tanks)).
* [Krastorio 2](https://mods.factorio.com/mod/Krastorio2) — interstellar communicator icon.
* [Subnautica](https://unknownworlds.com/subnautica/) by Unknown Worlds Entertainment — ferrous nodule, cupric
  nodule and cobalt ingot icons.

Everything else (and every graphic referenced by a `__base__`, `__core__`, `__space-age__`, `__quality__` or
`__elevated-rails__` path) is Factorio's own art, used as Wube Software allows for mods. It is not included in this
repository. The map previews in `docs/` are renders of the mod's map generation.

## Dependencies (not included)

These are separate mods, downloaded from the mod portal, each under its own licence:

* [Cargo Ships](https://mods.factorio.com/mod/cargo-ships), [BZ Lead](https://mods.factorio.com/mod/bzlead),
  [BZ Titanium](https://mods.factorio.com/mod/bztitanium), [Robot256Lib](https://mods.factorio.com/mod/Robot256Lib),
  [Spidertron Enhancements](https://mods.factorio.com/mod/SpidertronEnhancements),
  [Spidertron Patrols](https://mods.factorio.com/mod/SpidertronPatrols), [flib](https://mods.factorio.com/mod/flib).
* [Fluid Must Flow](https://mods.factorio.com/mod/FluidMustFlow) (LGPL-3.0) — the duct landing of the subsea
  pipeline is built on its duct to ground at load time; none of its files are copied here.
* Optional integrations with other mods (`FreightForwarding/compatibility/`) only change those mods' prototypes when
  they are installed; none of their files are included.

## Trademarks

Factorio and Space Age are trademarks of Wube Software. Subnautica is a trademark of Unknown Worlds Entertainment.
This project is not affiliated with or endorsed by either.

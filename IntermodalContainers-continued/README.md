# Intermodal Containers (continued)

Continuation of [Intermodal Containers](https://mods.factorio.com/mod/IntermodalContainers) by Xorimuth and RedRafe
(developed from Deadlock's Crating Machine) for Factorio 2.1, while the original mod is not updated.
Licensed under GPL-3, see `license.txt`.

* Mod name: `IntermodalContainers-continued`. It can't be enabled together with the original.
* Prototype names (`ic-*`) and the public API are unchanged, so integrations of other mods keep working.
  Mods that check `mods["IntermodalContainers"]` by name need to also check `mods["IntermodalContainers-continued"]`.
* Changes from 2.1.3: see `changelog.txt`.

---

Developed from [Deadlock's Crating Machine](https://mods.factorio.com/mod/DeadlockCrating). Made to be used by [Freight Forwarding](https://mods.factorio.com/mod/FreightForwarding), but can be used standalone or with other mods.

Intermediate resources can be loaded into containers.
Most things are configurable in mod settings.
Intermodal Containers automatically detects loadable resources, so should work with most mods. If a mod wants to override the autodetection or add a new tier of containerization machine, there is an API, documented [here](https://github.com/tburrows13/IntermodalContainers/blob/master/prototypes/public.lua).

---

Thanks to Deadlock989 for the original mod, shanemadden for maintaining it, and RedRafe for helping me move my changes from Freight Forwarding to this standalone mod.
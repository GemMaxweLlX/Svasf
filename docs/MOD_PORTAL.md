# Публикация на mod portal

## Права
* **Freight Forwarding** (Xorimuth) и **Intermodal Containers** (Xorimuth, RedRafe) — GPL-3. Форк и публикация
  разрешены, если: сохранить файл лицензии (`LICENCE.txt` / `LICENSE`), указать исходных авторов, открыть исходники
  (ссылка на этот репозиторий) и публиковать изменённую версию тоже под GPL-3.
* Имена `FreightForwarding` и `IntermodalContainers` на портале принадлежат авторам — публикуем под своими:
  `FreightForwarding-continued` и `IntermodalContainers-continued`. Перед публикацией вежливо написать автору
  (Discord FF: https://discord.gg/pkJc4v9nfT) — возможно, он захочет передать мод.
* Графика и звуки мода — из оригинала (GPL-3) и из базовой игры (использование в модах разрешено правилами Wube).

## Сборка
```
python3 tools/build-portal.py            # dist/FreightForwarding-continued_<v>.zip + IntermodalContainers-continued_<v>.zip
python3 tools/build-portal.py --original # dist/FreightForwarding_<v>.zip (для себя, с исходным именем)
```
Сборка `-continued` меняет пути `__FreightForwarding__`, имя, заголовок, авторов, добавляет конфликт с оригиналом и
своё превью (`tools/thumbnail-continued.png`). Имена прототипов (`ff-*`) не меняются — чертежи совместимы. Сохранение
с оригинальным модом при переходе на `-continued` теряет скриптовые данные мода (карта и постройки остаются).
Проверено: сборка `-continued` загружается в Factorio 2.1.24 с Space Age, 81/81 тестов столкновений.

## Загрузка
1. https://mods.factorio.com → «Upload mod» → zip из `dist/`.
2. Заполнить: категория **Overhaul**, теги *Logistics, Trains, Transportation, Map generation*; лицензия **GPL-3.0**;
   ссылка на исходники — этот репозиторий.
3. Описание — текст ниже. Changelog портал берёт из `changelog.txt`.
4. Сначала опубликовать `IntermodalContainers-continued`, потом `FreightForwarding-continued` (зависимость).

---

## Текст страницы (EN)

**Freight Forwarding, continued for Factorio 2.1 and Space Age.**

A small overhaul focused on long-distance logistics: island terrain, ships, containers and resources far away.
Originally by Xorimuth; this is a continuation, with the author credited and the GPL-3 licence kept.

### Freight Forwarding as you know it
Island-based Nauvis, lead at the edge of the starting island, offshore oil, dredging nodules from the seabed,
titanium from other islands, titansteel smelted in faraway lava pools, rocket silos only in craters.
**Classic mode** (startup setting) keeps exactly this game, even with Space Age installed.

### With Space Age
* **Rocket tiers:** a light 500 kg silo in a crater on Nauvis, the normal silo from the first planet you visit, a
  heavy 2 t silo from Aquilo.
* **Planet supply chains:** cobalt and titansteel on Vulcanus, battery packs on Fulgora, refrigerated containers on
  Gleba, lithium battery packs and interplanetary freight science on Aquilo.
* **Container tiers:** refrigerated, light (fixed weight in rockets) and cryo containers; containers wear out and can be
  repaired or recycled.
* **Ships and trains per planet:** lava barges, swamp barges, icebreakers, fast and heavy cargo ships, locomotive and
  wagon tiers. Lightning storms over Fulgora's oil sea.
* **The seas of other planets:** scrap seamounts on Fulgora, fluorine seeps on Aquilo, dredger Mk2/Mk3.
* **Interstellar freight contracts** — the goal: the Long Caravan passes the solar system edge and takes cargo on the
  fly. Choose contracts, meet deadlines, build reputation, take special orders; every contract pays with a bonus.

### For every game
Port cranes, cable terminals and subsea cables laid between shores, offshore wind turbines and tidal generators, a spoilage sensor for trains,
a fuel depot, map tags, freight statistics.

### Required
Cargo Ships, Cargo Ships Oil Rig, BZ Lead, BZ Titanium; Intermodal Containers (continued) recommended.

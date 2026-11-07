# Freight Forwarding 2.0.0 — перенос на Factorio 2.1

Исходник: FreightForwarding 1.9.0 (Factorio 1.1), см. первый коммит. Мод лежит в `FreightForwarding/`.

## Что изменено

### Генерация мира (переписана полностью)
В 2.x noise-выражения — это **строки**, библиотеки `require "noise"` больше нет. Формулы остались те же, что в 1.x.

| Что | Файл | Как сделано в 2.x |
|---|---|---|
| Рельеф-острова `x-continents` | `prototypes/map-gen.lua` | Та же математика (IslandStart + правки FF): большой стартовый остров (~650–700 тайлов), пустой океан до ~850, дальше архипелаги. Октавы шума с переменной persistence собраны в `local_expressions`. |
| Переменные 1.1, которых больше нет | там же | `water_level`/`wlc_*` → `ff_water_level = 10·log2(control:water:size)`; стартовое озеро — `ff_starting_lake_elevation` через `distance_from_nearest_point` + `starting_lake_positions`. |
| Тайлы воды | `prototypes/water.lua`, `map-gen.lua` | `ff_water_autoplace(max_elevation, influence)` повторяет 1.1 `make_water_autoplace_settings`: мелководье (0, 25), вода (−2.5, 100), глубокая вода (−8, 200). |
| Ресурсы | `resource-autoplace/*`, `prototypes/resources.lua` | Свой resource-autoplace переписан на строки (`spot_noise`, `basis_noise`, `random_penalty`). Сохранены все особенности FF: «кольцо» свинца/железа у края стартового острова, `ideal_aux` через `ff_resource_spread`, отложенное появление урана/титана (>1800), лава-бассейны (>3000), подводные горы (высота < −20), кратеры для ракетных шахт (высота > 8, > 4000 тайлов). Наборы пятен (patch sets) общие с ванильным модулем, чтобы руды не перекрывались. |
| Враги дальше от старта | `prototypes/autoplace-updates.lua` | `distance` и `starting_area_radius` в выражениях врагов Нувиса заменяются на `/2.5` (строковой заменой; именованные аргументы не трогаются). Враги Глебы не затрагиваются. |
| Пресет карты | `prototypes/map-gen-presets.lua` | `terrain_segmentation`/`water` → контрол `water` (масштаб/покрытие). Убран `research_queue_setting`. Скалы идут по рельефу FF (`cliff_elevation = ff_cliff_elevation`). Пресет «ribbon world» удалён (в 1.9 он и так был скрыт). |
| Планета Нувис | `prototypes/planet-nauvis.lua`, `map-gen-presets.lua` | В 2.x генерация задаётся `planet.map_gen_settings`. Ресурсы/контролы FF и мелководье добавлены в списки Нувиса (только если списки там есть). Новая стартовая настройка **«Острова по умолчанию»** (вкл.) — острова FF даже с пресетом «По умолчанию» и в Space Age. |

### Прототипы
* `prototypes/legacy.lua` — конвертер формата 1.1 → 2.x, через него идут все `data:extend` мода: рецепты (`{"item", n}` → `{type, name, amount}`, `result`/`result_count`, `catalyst_amount`), флаг `"hidden"` → `hidden = true`, `hr_version` → HD-спрайт (и пути `__base__/…/hr-*.png` без префикса), `emissions_per_minute = {pollution = …}`, `fuel_category` → `fuel_categories`, fluid box (`base_area` → `volume`, подключения труб с `direction`), `graphics_set` у машин, маски коллизий, `rocket_launch_products`.
* `prototypes/collision-util.lua` — слои коллизий теперь прототипы `collision-layer`: `ff_non_deep_water`, `ff_deep_water`, `ff_platform`, `ff_water_object`, `ff_substitute_player`, `ff_underwater_pipe`, `ff_lava_pool`, `ff_lava_pool_water_tile`.
* `prototypes/data-util.lua` — свои функции для рецептов/технологий (вместо внутренностей `__bzlead__.data-util`); все безопасны: если чего-то нет, пишут в лог и не падают.
* Переименования 2.x: `stack-inserter` → `bulk-inserter`, `effectivity-module-3` → `efficiency-module-3`, `empty-barrel` → `barrel`, `advanced-electronics-2` → `processing-unit`, удалены красный/зелёный провод и **блок управления ракетой** (вместо +1 заряженной батареи на блок → +5 заряженных батарей на часть ракеты; без Space Age).
* Радары FF (сейсмосканер, сонар-буй, радар земснаряда) — `connects_to_other_radars = false` (в 2.x радары по умолчанию объединяются).
* Mini Trains, Spidertron Patrols, Lex's Aircraft, Hovercrafts, Canal Builder, Beautiful Bridge Railway стали **необязательными**: код интеграции срабатывает только если мод есть.
* Анимации главного меню FF отключены: это сохранения 1.1, их нужно перезаписать в 2.x.

### Скрипты (control)
`global` → `storage`; `event.created_entity` → `event.entity`; `on_entity_destroyed` → `on_object_destroyed` (`useful_id`); `rendering` возвращает `LuaRenderObject` (старые id из сохранений 1.1 конвертируются); логистические запросы через `LuaLogisticSection`; `get_contents()` — массив; `spill_item_stack{…}`; `entity.active` → `disabled_by_script`; `game.*_prototypes` → `prototypes.*`; статистика производства — по поверхностям; финал (коммуникатор) проверяется в `on_rocket_launch_ordered`, т.к. груз уходит в капсулу.

### Space Age (если включён)
* Нувис — острова FF, остальные планеты не меняются (враги/руды других планет не трогаются, нефть Аквилона не ограничивается).
* Ракетная шахта: на Нувисе — только в кратере (проверка скриптом, шахта возвращается игроку), на других планетах — где угодно.
* Отключены: спутник/космическая наука из ракет, коммуникатор-финал (у SA своя победа), +5 батарей на часть ракеты.
* Транспортная наука принимается всеми лабораториями, которые принимают логистическую (в т.ч. биолабораторией).

## Как проверено
* Синтаксис всех `.lua` — `luac5.2 -p`.
* `tools/mock-data-stage/harness.lua`: settings → data → data-updates → data-final-fixes на заглушках, в режимах без SA и с SA — **0 ошибок**, не осталось рецептов/масок/флагов в формате 1.1.
* `tools/mock-data-stage/check.lua`: все noise-выражения мода разобраны по грамматике 2.x, проверены имена функций, аргументов и переменных — **0 проблем**.
* `tools/mock-data-stage/preview.lua`: приблизительное превью рельефа (`docs/map-preview-approx.png`; шум Перлина вместо шума Factorio): стартовый остров ~670 тайлов, вокруг океан, дальше острова.

## Что НЕ проверено (нужно в игре)
Из окружения, где делался порт, нельзя было скачать Factorio и моды (сеть закрыта), поэтому мод **ни разу не запускался в игре**.

1. **Зависимости.** Нужны их версии под 2.1: Intermodal Containers, Cargo Ships, BZ Lead, BZ Titanium (обязательные), остальные — по желанию. Имена прототипов этих модов в 2.x (`water_transport`, `tank_ship`, `oil_rig`, `or_pole`, `ic-containerization-*`, `hcraft-*`…) взяты из версий 1.1; где имени нет, интеграция просто пропускается (см. `factorio-current.log`, строки `[FreightForwarding]`).
2. **Генерация мира.** Запустить `--generate-map-preview` и сравнить с 1.9: размер стартового острова, свинец/железо на краю острова (~775), нефть только на глубокой воде, лава-бассейны, кратеры. Если острова слишком мелкие/крупные — ручка `bias` в `prototypes/map-gen.lua` (−60), размер стартового острова — `island_scale` (2.1).
3. Нативные имена/свойства, в которых я не уверен на 100 %: функция `log2`, переменная `starting_lake_positions`, свойство `cliff_elevation` в `property_expression_names`, `backer_name` у радаров (обёрнуто в pcall), отключение ванильной победы за ракету.
4. Перенос сохранений 1.1 → 2.1 (Factorio это умеет, но с модами FF не проверялось).

## Чек-лист первого запуска
- [ ] Игра загружается до главного меню (без SA и с SA).
- [ ] В логе нет ошибок, просмотреть строки `[FreightForwarding] … not found`.
- [ ] Новая карта с пресетом «Freight Forwarding»: остров, свинец на краю, нефть в океане.
- [ ] Земснаряд ставится на подводную гору и строит платформу.
- [ ] Сонар-буй работает на нефти, сейсмосканер не работает у воды.
- [ ] Ракетная шахта ставится только в кратер (на Нувисе).
- [ ] Игрок плавает в воде (спасательный круг), машины в воду не заезжают.

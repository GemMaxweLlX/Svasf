# Проверка на своём ПК с Claude Code

Облачная сессия не видит ваш компьютер. Поэтому проверку на ПК делает **локальная** сессия Claude Code: в терминале
(`claude`) или в приложении Claude для ПК, запущенная в папке с клоном этого репозитория.

Что она сделает сама:
* запустит Factorio без окна (`--create` / `--benchmark`) в разных наборах модов, уже с **настоящей графикой**
  (в облаке были заглушки), проверит загрузку, тест столкновений и мод-самотест `tools/ff-selftest`;
* соберёт результат в отчёт.

Что останется вам: пункты с окнами и картинками из [LOCAL_TESTING.md](LOCAL_TESTING.md). Их проходит человек в игре.

## 1. Что скачать

Скачать с [mods.factorio.com](https://mods.factorio.com) для Factorio 2.1 (в игре: «Моды» → «Установить») или
положить zip-файлы в `D:\FACTORIO2.0\mods`. Версии — те, с которыми проверял я, новее тоже подойдут.

### Обязательно (основная проверка)
| Мод | Версия | Зачем |
|---|---|---|
| Freight Forwarding (из этого репозитория, `FreightForwarding_2.0.0.zip`) | 2.0.0 | сам мод |
| Intermodal Containers (continued) (`dist/IntermodalContainers-continued_2.1.5.zip`) | 2.1.5 | контейнеры |
| Fluid Must Flow | 1.5.1 | обязательная зависимость FF |
| Cargo Ships | 2.1.8 | корабли |
| Cargo Ships Graphics | — | графика кораблей (в облаке была заглушка) |
| Cargo Ships Oil Rig | 2.1.2 | нефтяные платформы |
| BZ Lead | 2.0.29 | свинец |
| BZ Titanium | 2.0.27 | титан |
| Robot256Lib | 2.1.4 | библиотека |
| Spidertron Enhancements | 1.11.0 | зависимость |
| Spidertron Patrols | 2.7.1 | зависимость |
| flib | 0.17.2 | библиотека |
| Space Age (DLC) | 2.1 | второй проход: расширенный режим |

### Krastorio 2
| Мод | Версия |
|---|---|
| Krastorio 2 | 2.1.4 |
| Krastorio 2 Assets | 2.1.0 (настоящий, в облаке была заглушка) |
| Krastorio 2 Menu Simulations | 2.1.0 |
| Change Inserter Drop Lane | 1.3.0 |
| Krastorio 2 Spaced Out | 2.0.19 (только со Space Age) |
| k2so-assets | 1.0.7 (настоящий) |

### Совместимость (по желанию, проверялось в облаке)
| Мод | Версия | Нужно ещё |
|---|---|---|
| Alien Biomes | 0.8.1 | Alien Biomes Graphics 0.8.0 |
| LTN — Logistic Train Network | 3.5.2 | |
| Project Cybersyn | 2.2.2 | bplib 2.1.4 |
| AAI Containers & Warehouses | 0.4.0 | |
| AAI Industry | 0.7.5 | |
| AAI Vehicles: Ironclad | 0.8.0 | |
| Factory Planner | 2.1.21 | |
| Helmod | 2.3.6 | |
| Rate Calculator | 3.4.2 | |
| Recipe Book for 2.1 | 1.0.0 | |
| Milestones | 1.5.2 | |
| Better Victory Screen | 2.1.1 | |
| Hovercrafts | 2.1.4 | |
| Aircraft (Space Age) | 2.3.5 | |
| Mini Trains | 2.1.0 | |
| Cerys, Moon of Fulgora | 4.25.0 | PlanetsLib 2.4.0 |
| Maraxsis | 1.41.1 | PlanetsLib 2.4.0 |
| Moshine | 1.2.13 | Moshine-assets 1.0.2, module-category-defaults 2.2.0 |
| Muluna, Moon of Nauvis | 2.9.15 | muluna-graphics 1.1.19, bplib 2.1.4, PlanetsLib 2.4.0, space-exploration-graphics, -4, -5 |
| Flare Stack | 4.3.1 | |

Планеты, Cerys, Maraxsis, Muluna, Moshine, K2 Spaced Out и Aircraft (Space Age) требуют DLC Space Age.

## 2. Запуск локальной сессии

1. Клон репозитория на ПК: `git clone` этого репозитория, ветка `ccr-1908e503-rczymd`.
2. В папке клона: `claude` (или откройте папку в приложении Claude для ПК).
3. Разрешите доступ к `D:\FACTORIO2.0` (при первом запросе прав выберите «разрешить для этой сессии»).
4. Вставьте задание ниже.

## 3. Задание для локальной сессии (скопировать целиком)

```
Проверь Freight Forwarding 2.0.0 на этом ПК. Factorio 2.1 установлен в D:\FACTORIO2.0
(исполняемый файл обычно D:\FACTORIO2.0\bin\x64\factorio.exe — найди его), мои моды в D:\FACTORIO2.0\mods.

Правила:
- Мою папку D:\FACTORIO2.0\mods НЕ меняй. Перед любыми действиями сделай копию mod-list.json и mod-settings.dat.
- Для тестов создай D:\FACTORIO2.0\ff-test\<набор>\ и копируй туда нужные zip/папки модов из D:\FACTORIO2.0\mods,
  свежий FreightForwarding_2.0.0.zip и dist\IntermodalContainers-continued_2.1.5.zip из репозитория,
  а также папку tools\ff-selftest (мод-самотест). В каждой папке пиши свой mod-list.json и удаляй mod-settings.dat.
- Если какого-то мода нет в D:\FACTORIO2.0\mods — не скачивай, а пропусти набор и запиши, чего не хватило
  (список модов — docs\LOCAL_SESSION.md).

Наборы: (1) только FF и зависимости; (2) + Space Age, quality, elevated-rails; (3) то же с FF в классическом
режиме (ff-classic-mode = true: временно поменяй default_value в копии settings.lua внутри тестовой папки);
(4) + Krastorio 2; (5) Space Age + Krastorio 2 + K2 Spaced Out; (6) Space Age + все моды совместимости
из docs\LOCAL_SESSION.md, что есть на диске.

Для каждого набора:
  factorio.exe --mod-directory <папка> --create <папка>\test.zip --map-gen-seed 12345
  factorio.exe --mod-directory <папка> --benchmark <папка>\test.zip --benchmark-ticks 2800
Лог Factorio при этом — %APPDATA%\Factorio\factorio-current.log (или рядом с factorio.exe, если установка
портативная) — сохраняй копию после каждого запуска.
Проверь в логах: нет строк "Error"/"non-recoverable"; есть "CollisionTest finished: 81 tests passed, 0 tests failed";
строки "FFSELFTEST ..." и итог "FFSELFTEST SUMMARY N passed, 0 failed" (в классическом режиме цистерн нет — SKIP).
Отдельно проверь, что при запуске клиента с графикой нет ошибок загрузки спрайтов: запусти factorio.exe
с --mod-directory набора (6) обычным образом, дождись главного меню, закрой игру и посмотри лог.

В конце: таблица набор → ошибки / CollisionTest / FFSELFTEST, точный текст всех ошибок с путями файлов, и чего
не хватило. Ничего в коде не исправляй, только отчёт. Восстанови мой mod-list.json, если он менялся.
```

## 4. Что прислать в облачную сессию

Отчёт локальной сессии (таблицу и текст ошибок) и, если были ошибки, файлы `factorio-current.log` из тестовых папок.
По ним я исправлю мод здесь.

# Проверка мода без Factorio

Набор Lua-скриптов (Lua 5.2, как в Factorio), которые прогоняют data-стадию мода на заглушках и проверяют
noise-выражения генерации мира. Они **не заменяют** запуск в игре: заглушки знают только то, что нужно моду,
а шум Перлина в превью лишь приближённо повторяет `basis_noise` Factorio.

```sh
cd tools/mock-data-stage

# 1. settings → data → data-updates → data-final-fixes на заглушках (без Space Age / с Space Age)
lua5.2 harness.lua ../../FreightForwarding base noise-base.lua
lua5.2 harness.lua ../../FreightForwarding sa   noise-sa.lua
#    ловит ошибки выполнения и остатки формата 1.1 (рецепты, флаг "hidden", hr_version, маски коллизий)

# 2. Разбор всех noise-выражений по грамматике 2.x: неизвестные функции, переменные, именованные аргументы
lua5.2 check.lua noise-base.lua

# 3. Приблизительное превью рельефа (PPM): половина размера в тайлах, шаг, сид
lua5.2 preview.lua noise-base.lua preview.ppm 6144 48 12345
```

Настоящая проверка — в игре:

```sh
factorio --generate-map-preview preview.png --map-preview-size 2048 --map-preview-scale 4 \
         --map-gen-settings map-gen-settings.json --mod-directory <папка с модами>
```

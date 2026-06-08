# fcov
[![License](https://img.shields.io/badge/License-COPL-red.svg)](https://raw.githubusercontent.com/VitaSound/fcov/refs/heads/main/LICENSE)
[![Ver](https://img.shields.io/badge/Ver-0.3.1-green.svg)](https://github.com/VitaSound/fcov/releases/tag/0.3.1)
[![Cov](https://img.shields.io/badge/Cov-81%25-green.svg)](https://github.com/VitaSound/fcov/actions/workflows/ci.yml)

**Сборщик покрытия для Forth-кода.** Запускает тесты под
инструментацией и сообщает, какие `:`-определённые слова реально
вызывались. Консольная таблица, JSON, LCOV trace data и автономный
HTML-сайт — выбирай нужный формат.

> **0.3.0** — это уже настоящий инструментатор (definition + call
> coverage) и все четыре формата отчётов. Покрытие веток
> (`IF`/`ELSE`/`?DO`/…) — следующая большая цель, см.
> [doc/ROADMAP.md](doc/ROADMAP.md).

Часть **VitaSound Forth tooling family** —
[fmix](https://github.com/VitaSound/fmix) (сборка/тесты),
[flint](https://github.com/VitaSound/flint) (линтер),
[fsemver](https://github.com/VitaSound/fsemver) (общий движок
version-pinning), [fenum](https://github.com/VitaSound/fenum),
[ttester](https://github.com/VitaSound/ttester).

## Установка

```bash
cd ~ && git clone git@github.com:VitaSound/fcov.git
cd fcov && fmix packages.get
```

## Настройка shell

В `~/.bashrc` (или `~/.zshrc`) — **две строки только для этого инструмента** (конвенция VitaSound: один инструмент — одна пара строк PATH):

```bash
export FCOV_HOME="<install-dir>/fcov"
export PATH="$FCOV_HOME/bin:$PATH"
```

`<install-dir>` — родитель клонов (`$HOME` при feco в `~/feco`, или например `/opt/vitasound`). Массовая установка: [VitaSound/feco](https://github.com/VitaSound/feco) — `./scripts/clone-ecosystem.sh`. Канон: [feco shell setup](https://github.com/VitaSound/feco/blob/main/docs/shell-setup.ru.md).

Затем `source ~/.bashrc` и `fcov version`.

Соседние CLI (fmix, flint, fmcp, fhdlgen) — свои пары строк: [feco shell setup](https://github.com/VitaSound/feco/blob/main/docs/shell-setup.ru.md).

## Быстрый старт

```bash
cd /path/to/your/forth/project

fcov run                    # тестовая команда по умолчанию: `fmix test`
fcov run lein test          # либо любая другая shell-команда

fcov report                 # консольная сводка (та же, что в конце run)
fcov report --format html   # автономный сайт под .fcov/html/
fcov report --format json   # канонический JSON в stdout
fcov report --format lcov   # LCOV trace data в stdout
```

`fcov run` обходит дерево проекта, собирает каждое `:`-определённое
слово и его координаты в исходнике, генерирует instrumentation-prelude
(redefines `:`), запускает тестовую команду с этим prelude'ом
предзагруженным, и мерджит per-process call shards в
`./.fcov/coverage.json`. `fcov report` потом перечитывает эти данные
и рендерит их в нужном формате.

## CLI

```
fcov run [<test-cmd>]                  Запустить тесты под инструментацией
                                       (по умолчанию: `fmix test`).
fcov report [--format <fmt>]           Сгенерировать отчёт
                                       (по умолчанию: --format console).
fcov clean                             Удалить .fcov/-каталог.
fcov version                           Показать версию fcov.
fcov help                              CLI-справка.
```

## Форматы отчёта

| `--format` | Что получаешь | Куда уходит |
|------------|---------------|-------------|
| `console`  | человекочитаемая таблица с цветовой подсказкой, по строке на файл, плюс срезанный список не покрытых слов | stdout (также автоматически в конце `run`) |
| `json`     | канонический `coverage.json` — определения, hit-counts, summary. Стабильная схема, удобно скармливать в `jq`, дашборды, CI-гейты. | stdout |
| `lcov`     | [LCOV](#что-такое-lcov) trace data — `TN`/`SF`/`FN`/`FNDA`/`DA`/`LF`/`LH`/`end_of_record`. Любой LCOV-aware tooling: `genhtml`, GitLab/GitHub LCOV-вьюверы, IntelliJ, Sonar и т.д. | stdout |
| `html`     | автономный статичный сайт под `.fcov/html/` — `index.html` со сводной таблицей плюс по странице на исходный файл с полным текстом, подсветкой покрытых/непокрытых слов, hit-counts и якорями на номера строк. Без JS, без внешних шрифтов; работает офлайн. | каталог `.fcov/html/` |

### Что такое LCOV?

[LCOV](https://github.com/linux-test-project/lcov) — исторический
plain-text формат, в котором мир C/C++ хранит line- и
function-coverage с начала 2000-х. trace-файл выглядит так:

```
TN:fcov
SF:./fcov/util.4th
FN:12,fcov.str-dup
FN:18,fcov.str-concat
FNDA:14,fcov.str-dup
FNDA:6,fcov.str-concat
DA:12,14
DA:18,6
LF:2
LH:2
end_of_record
```

Записи группируются по файлам. `FN:<line>,<name>` объявляет
функцию/слово на конкретной строке, `FNDA:<count>,<name>` — сколько
раз вызвалось, `DA:<line>,<count>` — счётчик на строку, `LF`/`LH` —
итоги по строкам. fcov мапит каждое `:`-определённое слово на пару
`DA`/`FNDA` его исходной строки, чтобы любой LCOV-tooling — в первую
очередь
[`genhtml`](https://manpages.debian.org/testing/lcov/genhtml.1.en.html),
который генерит многостраничный HTML — получал согласованную картинку,
несмотря на то что мы измеряем покрытие *слов*, а не строк.

```bash
fcov report --format lcov > coverage.info
genhtml coverage.info -o coverage-html/
```

Родной `--format html` лучше, когда нужны fcov-специфичные цвета,
ссылки и таблицы по бакетам; `lcov` — правильный выбор, когда у тебя
уже есть toolchain (CI-дашборд, JetBrains coverage gutter, SonarQube),
который этот формат и так понимает.

## Что значит «покрытие» здесь

| Уровень | Что | 0.2.0 / 0.3.0 | 1.0.0 (цель) |
|---------|-----|---------------|---------------|
| **Definition** | каждое `:`/`defer`/`variable`/`constant`… в проекте определено и подгружено | ✅ | ✅ |
| **Call** | каждое `:`-определённое слово вызвано хотя бы одним тестом | ✅ | ✅ |
| **Call counts** | сколько раз вызывалось каждое слово | ✅ | ✅ |
| **Branch** | обе ветки `IF`/`ELSE`, тело `WHILE`/`UNTIL`/`?DO` etc. пройдены | — | ✅ |

Процент покрытия считается **только по `:`-определённым словам**:
переменные/константы попадают в каталог с `calls = 0`, но не тянут
метрику вниз.

## Исключение путей

Добавь строки `key-list fcov-exclude <prefix>` в свой `package.4th` —
матчащие пути исключаются из обхода:

```forth
forth-package
    key-value name myproj
    key-value version 0.1.0
    key-value main src/myproj.4th
    key-value fcov ~> 0.3

    key-list fcov-exclude tests/fixtures
    key-list fcov-exclude src/legacy
end-forth-package
```

`build/`, `forth-packages/`, `.fcov/` и любое имя, начинающееся с `.`,
исключаются безусловно — exclude-list нужен поверх этого, для
проектных конвенций.

## Привязка версии (`key-value fcov ~> X.Y`)

Та же грамматика Elixir/Hex, что у fmix и flint — делегирована
[fsemver](https://github.com/VitaSound/fsemver), чтобы все три
инструмента понимали ровно один и тот же набор операторов:

```forth
forth-package
    key-value name myproj
    key-value version 0.1.0
    key-value main myproj.4th
    key-value fcov ~> 0.3
end-forth-package
```

| Запись | Что означает |
|--------|--------------|
| `key-value fcov ~> 0.3` | `>= 0.3.0` и `< 1.0.0` (MAJOR зафиксирован) |
| `key-value fcov ~> 0.3.1` | `>= 0.3.1` и `< 0.4.0` (MAJOR+MINOR зафиксированы) |
| `key-value fcov >= 0.3.0` | минимум, без верхней границы |
| `key-value fcov == 0.3.0` | ровно эта версия |
| `key-value fcov >  0.3.0` | строго больше |
| `key-value fcov <  1.0.0` | строго меньше |
| `key-value fcov <= 0.3.5` | меньше-или-равно |
| `key-value fcov 0.3.0`    | голая версия = `>= 0.3.0` |

Как и flint (но в отличие от fmix), **несоответствие — это WARN, а не
ERROR**: fcov сообщает о ситуации, но не отказывается работать. Данные
покрытия полезны даже от «не той» версии, а жёсткие ворота блокировали
бы CI по косметической причине.

Старый формат `key-list dependencies fcov <ver>` распознаётся и
печатается WARN с миграционной подсказкой.

## Тесты

```bash
bash tests/fcov_integration_test.sh
```

Integration-скрипт покрывает:
- пути `help`, `version`, `run`, `report`, `clean`, неизвестная команда
- warn-only поведение version-check (будущий req, legacy форма)
- `tests/fcov_smoke_test.4th` (util/wiring assertions)
- `tests/fcov_aggregator_test.4th` (мердж шардов, lookup, фильтр внешних)
- `tests/fcov_prelude_gen_test.4th` (round-trip сгенерированного
  prelude через свежий gforth-подпроцесс)
- `tests/fixtures/partial_cov/` end-to-end фикстура (golden split на
  covered/uncovered)
- `--format lcov` выдаёт genhtml-совместимый формат
- `--format html` генерирует рабочие index + per-file страницы
- `--format json` валидный coverage JSON

## Layout

| Path | Что |
|------|-----|
| `bin/fcov` | bash-лаунчер (TTY reset, передача env-vars, расширение `fpath`) |
| `fcov.4th` | entry point: парсинг аргументов, диспатч команд, оркестрация run/report |
| `fcov/util.4th` | строковые и файловые хелперы |
| `fcov/walk.4th` | рекурсивный обход `.4th`-дерева |
| `fcov/scan.4th` | per-file токенайзер; эмитит `(file, line, type, name)` события |
| `fcov/collect.4th` | in-memory список определений + writer для `defs.json` |
| `fcov/exclude.4th` | path-prefix фильтр на основе `key-list fcov-exclude` |
| `fcov/prelude.4th` | генератор per-process `:`-instrumentation prelude |
| `fcov/aggregate.4th` | мердж call-shard логов в `coverage.json` |
| `fcov/report-console.4th` | console-репортер |
| `fcov/report-lcov.4th` | LCOV-trace-репортер |
| `fcov/report-json.4th` | stdout-JSON-репортер |
| `fcov/report-html.4th` | статический HTML-сайт-репортер |
| `fcov/version-check.4th` | читает `key-value fcov <req>` из `./package.4th` и печатает WARN, если установленный fcov не подходит (парсинг/матчинг делегированы [fsemver](https://github.com/VitaSound/fsemver)). |
| `doc/ROADMAP.md` | полный план для 1.0.0 (branch coverage) |
| `tests/fcov_*_test.4th` | прямые gforth-юнит-тесты |
| `tests/fcov_integration_test.sh` | чёрно-ящичные CLI-integration-тесты |
| `tests/fixtures/partial_cov/` | end-to-end фикстура-проект |
| `package.4th` | theforth.net метаданные + зависимости |

## Публикация на theforth.net

[theforth.net](https://theforth.net/) — официальный реестр Forth-пакетов.

Краткая инструкция (по [guidelines](https://theforth.net/guidelines)):

1. Создай аккаунт: <https://theforth.net/profile>.
2. Проверь `package.4th` — у fcov он уже соответствует guidelines.
3. Собери архив. **Корневая папка должна совпадать с `name`** (`fcov`):

   ```bash
   cd ~
   tar czf fcov-0.3.0.tar.gz \
       --exclude='fcov/.git' \
       --exclude='fcov/forth-packages' \
       --exclude='fcov/build' \
       --exclude='fcov/.fcov' \
       fcov
   ```

4. Залогинься на theforth.net, перейди в
   [Profile](https://theforth.net/profile), загрузи архив.

5. После публикации НЕ меняй `version` для уже выложенного слота —
   повышай по SemVer: **PATCH** для багфикса, **MINOR** для нового
   функционала, **MAJOR** для несовместимого изменения API.

## Лицензия

[COPL](LICENSE) — Communist Public License. Используйте свободно,
делитесь с другими.

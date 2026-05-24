# fcov

**Сборщик покрытия для Forth-кода.** Запускает тесты под
инструментацией и сообщает, какие `:`-определённые слова (и, в 0.2.0+,
какие ветки `IF`/`ELSE`) были реально пройдены.

> **0.1.0 — скелетный релиз.** CLI-поверхность, version pinning,
> лаунчер, тесты, документация и релиз-процесс готовы; сама
> инструментация и репортер — заглушки. См.
> [doc/ROADMAP.md](doc/ROADMAP.md) для полного плана. 1.0.0 — цель
> «покрытие реально работает».

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

Добавь в `~/.bashrc` — по одной строке на инструмент, чтобы каждый
можно было передвинуть/убрать независимо:

```bash
export FCOV_HOME="$HOME/fcov"
export PATH="$FCOV_HOME/bin:$PATH"
```

Проверка:

```
$ fcov version
** (fcov) v0.1.0
```

## CLI (целевой вид, после 0.1.0)

```
fcov run [<test-cmd>]                      Запустить тесты под инструментацией
                                           (по умолчанию: `fmix test`).
fcov report [--format console|lcov|json|html]
                                           Показать отчёт по покрытию из
                                           последнего run.
fcov clean                                 Удалить .fcov/ артефакты.
fcov version                               Показать версию fcov.
fcov help                                  Эту справку.
```

В 0.1.0 `run` и `report` печатают заглушку вместо реальной работы;
`clean`, `version` и `help` работают полноценно.

## Что значит «покрытие» здесь

| Уровень | Что | 0.1.0 | 0.2.0 (цель) | 1.0.0 |
|---------|-----|-------|--------------|-------|
| **Definition** | каждое `:`/`Defer`/`Variable` в проекте определено и подгружено | scaffold | ✅ | ✅ |
| **Call** | каждое определённое слово вызвано хотя бы одним тестом | scaffold | ✅ | ✅ |
| **Call counts** | сколько раз вызывалось каждое слово | scaffold | ✅ | ✅ |
| **Branch** | обе ветки `IF`/`ELSE`, тело `WHILE`/`UNTIL`/`?DO` etc. пройдены | scaffold | — | ✅ |

Покрытие собирается во время `fcov run` и агрегируется в
`./.fcov/coverage.json`. Репортер читает этот файл — `run` и `report`
разнесены, чтобы переформатировать одни и те же данные несколько раз
без повторного прогона тестов.

## Привязка версии (`key-value fcov ~> X.Y`)

Та же грамматика Elixir/Hex, что у fmix и flint — делегирована
[fsemver](https://github.com/VitaSound/fsemver), чтобы все три
инструмента понимали ровно один и тот же набор операторов:

```forth
forth-package
    key-value name myproj
    key-value version 0.1.0
    key-value main myproj.4th
    key-value fcov ~> 0.1
end-forth-package
```

| Запись | Что означает |
|--------|--------------|
| `key-value fcov ~> 0.1` | `>= 0.1.0` и `< 1.0.0` (MAJOR зафиксирован) |
| `key-value fcov ~> 0.1.3` | `>= 0.1.3` и `< 0.2.0` (MAJOR+MINOR зафиксированы) |
| `key-value fcov >= 0.1.0` | минимум, без верхней границы |
| `key-value fcov == 0.1.0` | ровно эта версия |
| `key-value fcov >  0.1.0` | строго больше |
| `key-value fcov <  1.0.0` | строго меньше |
| `key-value fcov <= 0.1.5` | меньше-или-равно |
| `key-value fcov 0.1.0`    | голая версия = `>= 0.1.0` |

Как и flint (но в отличие от fmix), **несоответствие — это WARN, а не
ERROR**: fcov сообщает о ситуации, но не отказывается работать. Данные
покрытия полезны даже от «не той» версии, а жёсткие ворота блокировали
бы CI по косметической причине. В будущей мажорной версии может
ужесточиться.

Старый формат `key-list dependencies fcov <ver>` распознаётся и
печатается WARN с миграционной подсказкой.

## Тесты

```bash
bash tests/fcov_integration_test.sh
```

Integration-скрипт покрывает:
- пути `help`, `version`, `run`, `report`, `clean`, неизвестная команда
- warn-only поведение version-check (будущий req, legacy форма)
- `tests/fcov_smoke_test.4th` (прямой gforth-смоук цепочки
  fsemver-через-version-check)

Полная 71-кейсовая truth-table операторов лежит выше — в
`forth-packages/fsemver/0.1.0/tests/fsemver_test.4th`, мы её здесь не
дублируем.

## Layout

| Path | Что |
|------|-----|
| `bin/fcov` | bash-лаунчер (TTY reset, передача env-vars, расширение `fpath`) |
| `fcov.4th` | entry point: парсинг аргументов, диспатч команд, CLI-заглушки |
| `fcov/util.4th` | строковые и файловые хелперы |
| `fcov/version-check.4th` | читает `key-value fcov <req>` из `./package.4th` и печатает WARN (не блокирует), если установленный fcov не подходит. Парсинг / матчинг делегированы [fsemver](https://github.com/VitaSound/fsemver). |
| `doc/ROADMAP.md` | полный план реализации для 0.2.0 (instrumentation) и 1.0.0 (branch coverage) |
| `tests/fcov_smoke_test.4th` | прямой gforth wiring-смоук |
| `tests/fcov_integration_test.sh` | чёрно-ящичные CLI integration-тесты |
| `package.4th` | theforth.net метаданные + зависимости |

## Публикация на theforth.net

[theforth.net](https://theforth.net/) — официальный реестр Forth-пакетов.

Краткая инструкция (по [guidelines](https://theforth.net/guidelines)):

1. Создай аккаунт: <https://theforth.net/profile>.
2. Проверь `package.4th` — у fcov он уже соответствует guidelines.
3. Собери архив. **Корневая папка должна совпадать с `name`** (`fcov`):

   ```bash
   cd ~
   tar czf fcov-0.1.0.tar.gz \
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

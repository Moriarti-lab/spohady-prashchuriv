# AGENTS.md — «Спогади пращурів»

Android action-RPG на **Godot 4.7.2** (GDScript, GL Compatibility). Пробная версия 0.6.0.
Главная сцена — `res://scenes/boot.tscn`. Язык игровых текстов — украинский.

## Окружение на этой машине (Windows)

| Инструмент | Путь |
|---|---|
| Godot 4.7.2 (GUI) | `C:\Users\Xako\Tools\Godot\godot.exe` |
| Godot 4.7.2 (консоль, для CLI) | `C:\Users\Xako\Tools\Godot\godot_console.exe` |
| JDK 17 | `C:\Users\Xako\Tools\jdk-17` (`JAVA_HOME`) |
| Android SDK | `C:\Users\Xako\AppData\Local\Android\Sdk` (`ANDROID_HOME`) |
| adb | `...\Android\Sdk\platform-tools\adb.exe` |
| Git (+ Git Bash) | `C:\Users\Xako\Tools\PortableGit` |

Шаблоны экспорта установлены в `%APPDATA%\Godot\export_templates\4.7.2.stable`.
`JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT` и пути SDK/Git/Godot уже прописаны в пользовательский `PATH`.
`core.autocrlf=false` — Godot пишет LF, не включай обратно.

## Команды

```powershell
# импорт ресурсов (после клонирования или массовых правок ассетов)
godot_console --headless --path . --import

# смоук-тест игры (1–2 минуты, без окна)
godot_console --headless --path . res://tests/smoke_test.tscn

# сборка debug APK
godot_console --headless --path . --export-debug "Android debug" "build/spohady-v0.6.0.apk"

# установка на подключённый телефон
adb install -r build/spohady-v0.6.0.apk

# открыть проект в редакторе
godot --path . -e
```

`godot_console` = `C:\Users\Xako\Tools\Godot\godot_console.exe`. Для экспорта нужны
`JAVA_HOME` и `ANDROID_HOME`; ключ по умолчанию — `%APPDATA%\Godot\keystores\debug.keystore`
(alias `androiddebugkey`, пароль `android`).

## Тесты

`tests/run_all.sh` — основной набор (Game + Editor). Запускать через Git Bash:
`C:\Users\Xako\Tools\PortableGit\bin\bash.exe tests/run_all.sh`.
На этой машине уже стоят `node` 26.13.1 и `python3` 3.15.2 (обёртка `python3.cmd` над
`python.exe`), оба в `PATH` — значит все шаги с `node`/`python3` работают локально.
Шаги под `xvfb-run` (flow, nauzi_ui, layout_regression, sell_cancel) на Windows
пропускаются сами по себе (`command -v`), это нормально — их покрывает CI.
CI (`.github/workflows/tests.yml`) гоняет всё на Ubuntu с Godot 4.7.2 — локальная
версия движка должна совпадать.

## Правила проекта

- Версия движка зафиксирована: **4.7.2** (другая версия может иначе импортировать ассеты).
- `export_presets.cfg`: только `arm64-v8a`, подпись debug-ключом, пакет `com.moriartilab.spohady`.
  Есть второй пресет «Android editor» (`com.moriartilab.spohady.editor`).
- Данные — в `data/*.json` (`perk_tree.json`, `icons.json`, `stat_registry.json`).
  После правок дерева в `tools/tree-editor*/index.html` синхронизировать:
  `python3 tools/sync_editor_tree.py` (не запускать без реальных изменений).
- `tools/gen_descriptions.py --check` и `tools/check_tree_seed.py` — проверки описаний и seed.
- Не менять `SAVE_VERSION` без миграции: старые сохранения должны читаться.
- `tests/`, `docs/`, `tools/` исключены из APK (`exclude_filter`).
- Файлы `.uid` (Godot 4.4+) и `.import` коммитить вместе с ассетами.
- `build/`, `.godot/`, `android/`, `*.keystore`, `export_credentials.cfg` — в `.gitignore`.

## Полезное

- `README.md` — что в релизе, управление на ПК (WASD, J — удар, 1–4 — навыки, B — сумка, P — Древо).
- `docs/todo_next.md` — что дальше (LayoutApply сумки, display-only статы, релиз v0.6.0).
- `docs/handoff_2026-11-07.md` — история решений и текущие ограничения.

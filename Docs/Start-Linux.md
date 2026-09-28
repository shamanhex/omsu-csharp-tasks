# Старт с нуля: Linux

Инструкция проходится **один раз** сверху вниз. Команды копируйте целиком и вставляйте в терминал (`Ctrl+Shift+V`), затем нажимайте `Enter`.

Команды установки даны для **Ubuntu / Debian / Linux Mint**. Для Fedora замените `apt` на `dnf`, для других дистрибутивов см. раздел «Если пакет не найден».

Другие ОС: [Windows](./Start-Windows.md) · [macOS](./Start-macOS.md)

## Шаг 0. Откройте терминал

Нажмите `Ctrl+Alt+T` (или найдите «Терминал» в меню приложений).

> **Регистр букв важен.** В Linux `src/Labs` и `src/labs` — разные папки. Чтобы не ошибаться, набирайте начало имени и нажимайте `Tab` — терминал допишет его сам.

## Шаг 1. Проверьте, что всё установлено

Выполните по очереди три команды:

```bash
git --version
```

```bash
dotnet --list-sdks
```

```bash
pwsh --version
```

Правильный результат:

| Команда | Что должно быть | Пример |
|---|---|---|
| `git --version` | любая версия | `git version 2.43.0` |
| `dotnet --list-sdks` | **есть строка, начинающаяся с `10.`** | `10.0.103 [/usr/lib/dotnet/sdk]` |
| `pwsh --version` | 7.x | `PowerShell 7.5.2` |

Сообщение `command not found` означает, что программа не установлена — см. ниже.

### Установка Git

```bash
sudo apt update
sudo apt install -y git
```

`sudo` попросит пароль вашего пользователя. **При вводе пароля символы не отображаются** — это нормально, просто наберите его и нажмите `Enter`.

### Установка .NET SDK 10.0

```bash
sudo apt install -y dotnet-sdk-10.0
```

Если выдано `Unable to locate package dotnet-sdk-10.0` — ваша версия Ubuntu слишком старая для этого пакета. На Ubuntu 22.04 / 24.04 подключите репозиторий и повторите:

```bash
sudo add-apt-repository -y ppa:dotnet/backports
sudo apt update
sudo apt install -y dotnet-sdk-10.0
```

### Установка PowerShell

```bash
sudo snap install powershell --classic
```

### Если пакет не найден (любой дистрибутив)

Универсальный способ — установить в домашнюю папку, без `sudo`.

.NET SDK 10.0:

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh -o ~/dotnet-install.sh
bash ~/dotnet-install.sh --channel 10.0
echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools' >> ~/.bashrc
source ~/.bashrc
```

PowerShell (после установки .NET):

```bash
dotnet tool install --global PowerShell
echo 'export PATH=$PATH:$HOME/.dotnet/tools' >> ~/.bashrc
source ~/.bashrc
```

> **Важно:** после любой установки **закройте терминал и откройте новый**, затем повторите Шаг 1.

## Шаг 2. Разрешение запуска скриптов

В Linux ничего делать не нужно: ограничение `ExecutionPolicy` действует только в Windows. Переходите к Шагу 3.

## Шаг 3. Скачайте проект

Перейдите в домашнюю папку и скачайте репозиторий:

```bash
cd ~
git clone https://github.com/shamanhex/omsu-csharp-tasks.git
```

Появится папка `~/omsu-csharp-tasks` (то есть `/home/<ваше имя>/omsu-csharp-tasks`).

> Ошибка `destination path 'omsu-csharp-tasks' already exists` значит, что проект уже скачан. Повторно клонировать не нужно — переходите к Шагу 4.

## Шаг 4. Перейдите в папку проекта

```bash
cd ~/omsu-csharp-tasks/src/Labs
```

Строка приглашения изменится и будет заканчиваться на `omsu-csharp-tasks/src/Labs$`. **Все следующие команды выполняются из этой папки.**

Когда вы откроете новый терминал (например, на следующий день), начинайте именно с этой команды.

## Шаг 5. Соберите проект

```bash
dotnet build
```

Первая сборка может занять до минуты. В конце должно быть написано `Build succeeded` и `0 Error(s)`.

Если есть строки с `error CS....` — в коде ошибка, текст подсказывает файл и номер строки.

Собранная программа лежит здесь: `bin/Debug/net10.0/Labs` (в Linux у программ нет расширения `.exe`).

**После каждого изменения кода запускайте `dotnet build` заново**, иначе запустится старая версия программы.

## Шаг 6. Запустите программу

Без аргументов:

```bash
./bin/Debug/net10.0/Labs
```

С аргументами (пример для Lab01):

```bash
./bin/Debug/net10.0/Labs --task 1 -x 1 -y 2 -z 3
```

Для исходного шаблона проекта результат будет таким:

```
HELP: No help, life is hard!
```

> `./` в начале обязательно: так терминал понимает, что программу надо искать в текущей папке.

Альтернатива — собрать и запустить одной командой (аргументы программы пишутся после `--`):

```bash
dotnet run -- --task 1 -x 1 -y 2 -z 3
```

## Шаг 7. Запустите автотесты

Сначала обязательно выполните `dotnet build` (Шаг 5). Затем:

```bash
pwsh ../UAT.Labs/RunCheckLab01.ps1 -Variant 1
```

Вместо `1` укажите **свой** номер варианта. Если `-Variant` не указать, скрипт спросит его сам.

Для других лабораторных меняется только номер в имени скрипта: `RunCheckLab02.ps1`, `RunCheckLab03.ps1` и т.д.

### Как читать результат

```
TEST [OK]: Запуск без аргументов
    CMD: ./src/Labs/bin/Debug/net10.0/Labs
    OUTPUT: HELP: No help, life is hard!

TEST [ERR]: Ввод числа вне диапазона [--task 2]
    CMD: ./src/Labs/bin/Debug/net10.0/Labs --task 2 -x 1 -y 2 -z -1
    ACTUAL: HELP: No help, life is hard!
    EXPECTED: ERROR: Unknown task. Task number must not exceed 1.
    COMMENT: Ожидалась ошибка (первая строка должна начинаться с 'ERROR'), ...
...
Итог: OK: 1, ERR: 10, WARN: 0
```

- `[OK]` — тест пройден.
- `[ERR]` — тест не пройден. Сравните `ACTUAL` (что вывела ваша программа) и `EXPECTED` (что ожидалось), прочитайте `COMMENT`.
- `[WARN]` — программа не завершилась за 5 секунд. Чаще всего в конце стоит `Console.ReadKey()` / `Console.ReadLine()` — уберите их.
- `CMD` — точная команда запуска (путь указан от корня репозитория). Её можно выполнить вручную (Шаг 6), чтобы посмотреть на поведение программы.

На пустом шаблоне почти все тесты падают — это нормально, их и нужно «починить» своей реализацией. Лабораторная готова, когда `ERR: 0`.

## Частые проблемы

| Сообщение | Что делать |
|---|---|
| `command not found` | Программа не установлена или терминал открыт до установки. См. Шаг 1, откройте новый терминал. |
| `No such file or directory` | Опечатка в пути или неверный регистр букв (`labs` вместо `Labs`). Используйте `Tab` для автодополнения. |
| `MSBUILD : error MSB1003: Specify a project or solution file` | Вы не в той папке. Выполните `cd ~/omsu-csharp-tasks/src/Labs`. |
| `NETSDK1045: The current .NET SDK does not support targeting .NET 10.0` | Установлен старый .NET SDK. Установите 10.0 (Шаг 1). |
| `You must install .NET to run this application` при запуске `./bin/.../Labs` | .NET установлен скриптом, но не задана переменная `DOTNET_ROOT`. Выполните строки с `echo 'export ...'` из раздела «Если пакет не найден» и откройте новый терминал. Либо запускайте через `dotnet run -- ...`. |
| `Permission denied` при запуске `./bin/.../Labs` | Выполните `chmod +x ./bin/Debug/net10.0/Labs`. |
| `Ошибка: исполняемый файл не найден.` (в автотесте) | Не выполнена сборка. Запустите `dotnet build`. |
| Проверить, в какой папке вы сейчас находитесь | Команда `pwd`. |

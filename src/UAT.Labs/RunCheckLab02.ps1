<#
.SYNOPSIS
    Автоматическая проверка лабораторной работы Lab02 (рекурсивный калькулятор).

.DESCRIPTION
    Запускает студенческий исполняемый файл и проверяет его вывод согласно
    критериям приёмки из Labs/Lab02.md, а также контрольным примерам из
    Labs/Lab02_ControlValues.csv (только для указанного варианта).

    В отличие от Lab01, при успешном расчёте программа выводит две строки:
    сначала "DAYS: <N>" (длина пересечения отрезков дат), затем
    "RESULT: <R>" (значение рекурсивной формулы, 3 знака после запятой).

    Кроссплатформенный (Windows / Linux / macOS): требуется только PowerShell
    (5.1 или 7+), дополнительные модули не нужны.

.PARAMETER ExePath
    Путь до исполняемого файла. По умолчанию - src\Labs\bin\Debug\net10.0\Labs.exe
    (с автоматическим поиском в src\Labs\bin, если файл не найден).

.PARAMETER Variant
    Номер варианта (1-8). Если не указан - запрашивается интерактивно.

.PARAMETER MaxTestRuntime
    Максимальное время одного запуска в секундах (по умолчанию 5).
    Зависание программы помечается как Warning, а не ошибка.

.EXAMPLE
    .\RunCheckLab02.ps1 -Variant 1

.EXAMPLE
    .\RunCheckLab02.ps1 -Variant 3 -ExePath D:\...\Labs.exe -MaxTestRuntime 10
#>

[CmdletBinding()]
param(
    [string]$ExePath,
    [int]$Variant,
    [int]$MaxTestRuntime = 5
)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Подключение общих функций (запуск процесса, поиск exe, вывод тестов и пр.)
. ([System.IO.Path]::Combine($scriptDir, 'Common.ps1'))

function Test-StudentOutput {
    param(
        [string]$Output,
        [object]$Test
    )

    $ExpectedKind   = $Test.Kind
    $ExpectedDays   = $Test.ExpectedDays
    $ExpectedResult = $Test.ExpectedResult

    $res = [PSCustomObject]@{
        Passed     = $false
        Comment    = ''
        ActualKind = 'None'
    }

    $lines = @()
    if ($null -ne $Output -and $Output.Length -gt 0) {
        $lines = @($Output -split '\r?\n' | Where-Object { $_ -match '\S' })
    }
    if ($lines.Count -eq 0) {
        $res.Comment = 'Вывод программы пуст: нет ни одной значимой строки'
        return $res
    }

    $first = $lines[0]

    if ($first -match '^\s*DAYS')        { $res.ActualKind = 'Success' }
    elseif ($first -match '^\s*HELP')    { $res.ActualKind = 'Help' }
    elseif ($first -match '^\s*ERROR')   { $res.ActualKind = 'Error' }
    else                                 { $res.ActualKind = 'Unknown' }

    switch ($ExpectedKind) {
        'Help' {
            if ($res.ActualKind -eq 'Help') {
                $res.Passed = $true
            } else {
                $res.Comment = "Ожидалась справка (первая строка должна начинаться с 'HELP'), а получено: '$first'"
            }
        }
        'Error' {
            if ($res.ActualKind -eq 'Error') {
                $res.Passed = $true
            } else {
                $res.Comment = "Ожидалась ошибка (первая строка должна начинаться с 'ERROR'), а получено: '$first'"
            }
        }
        'Success' {
            # Первая значимая строка: DAYS: <N>
            if ($first -notmatch '^\s*DAYS\s*:\s*(.+)$') {
                $res.Comment = "Первая значимая строка должна иметь вид 'DAYS: <N>', а получено: '$first'"
                return $res
            }
            $daysText = $Matches[1].Trim()
            if ($daysText -notmatch '^\d+$') {
                $res.Comment = "После 'DAYS:' ожидается целое неотрицательное число, а получено: '$daysText'"
                return $res
            }
            $actualDays = [int]$daysText
            if ($null -ne $ExpectedDays -and "$ExpectedDays" -ne '') {
                if ($actualDays -ne [int]$ExpectedDays) {
                    $res.Comment = "Значение DAYS не совпадает с эталоном: ожидалось $ExpectedDays, получено $actualDays"
                    return $res
                }
            }

            # Вторая значимая строка: RESULT: <R>
            if ($lines.Count -lt 2) {
                $res.Comment = "Ожидалась вторая значимая строка 'RESULT: <R>', но вывод содержит только одну значимую строку"
                return $res
            }
            $second = $lines[1]
            if ($second -notmatch '^\s*RESULT\s*:\s*(.+)$') {
                $res.Comment = "Вторая значимая строка должна иметь вид 'RESULT: <R>', а получено: '$second'"
                return $res
            }
            $value = $Matches[1].Trim()

            # Формат: ровно 3 знака после запятой, разделитель '.' или ','
            if ($value -notmatch '^[-+]?\d+[.,]\d{3}$') {
                $res.Comment = "Значение должно форматироваться до 3 знаков после запятой (например '120.000', а не '$value')"
                return $res
            }

            if (-not [string]::IsNullOrEmpty($ExpectedResult)) {
                $actualNum = [decimal]($value -replace ',', '.')
                $expectedNum = [decimal]($ExpectedResult -replace ',', '.')
                # Сравнение до 2 знаков после запятой, 3-й знак игнорируется (усечение)
                $a2 = [math]::Truncate($actualNum * 100)
                $e2 = [math]::Truncate($expectedNum * 100)
                if ($a2 -ne $e2) {
                    $res.Comment = "Значение не совпадает с эталоном до 2 знаков: ожидалось {0:0.00}, получено {1:0.00}" -f $expectedNum, $actualNum
                    return $res
                }
            }
            $res.Passed = $true
        }
    }

    return $res
}

# ===================== Основной поток =====================

$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$csvPath = [System.IO.Path]::Combine($repoRoot, 'Labs', 'Lab02_ControlValues.csv')
$defaultDir = [System.IO.Path]::Combine($repoRoot, 'src', 'Labs', 'bin', 'Debug', 'net10.0')

# --- Проверка варианта ---
if (-not $PSBoundParameters.ContainsKey('Variant')) {
    do {
        $answer = Read-Host 'Введите номер варианта (1-8)'
        if ($answer -match '^\d+$') { $Variant = [int]$answer } else { $Variant = 0 }
    } while ($Variant -lt 1 -or $Variant -gt 8)
}
if ($Variant -lt 1 -or $Variant -gt 8) {
    Write-Line "Ошибка: вариант должен быть целым числом от 1 до 8 (получено: $Variant)" -Color $ColorErr
    exit 2
}

if ($MaxTestRuntime -le 0) {
    Write-Line "Ошибка: MaxTestRuntime должен быть положительным (получено: $MaxTestRuntime)" -Color $ColorErr
    exit 2
}

# --- Поиск исполняемого файла ---
$resolvedExe = Resolve-ExePath -ProvidedPath $ExePath -RepoRoot $repoRoot
if ($null -eq $resolvedExe) {
    Write-Line 'Ошибка: исполняемый файл не найден.' -Color $ColorErr
    Write-Line "  Ожидаемое расположение: $defaultDir" -Color $ColorErr
    Write-Line '  Соберите проект: dotnet build src\Labs' -Color $ColorErr
    if (-not [string]::IsNullOrEmpty($ExePath)) {
        Write-Line "  Также проверьте переданный -ExePath: $ExePath" -Color $ColorErr
    }
    exit 2
}

# --- Способ запуска (dotnet для .dll) ---
$exeFile = $resolvedExe
$exePrefixArgs = @()
$exeDisplay = Get-DisplayPath -Path $resolvedExe -RepoRoot $repoRoot
if ($resolvedExe -match '\.dll$') {
    $exeFile = 'dotnet'
    $exePrefixArgs = @($resolvedExe)
    $exeDisplay = 'dotnet ' + (Get-DisplayPath -Path $resolvedExe -RepoRoot $repoRoot)
}

# --- Чтение контрольных примеров ---
if (-not (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
    Write-Line "Ошибка: не найден файл контрольных примеров: $csvPath" -Color $ColorErr
    exit 2
}
$csvRows = Import-Csv -LiteralPath $csvPath -Encoding UTF8

# --- Проверки из раздела "Приёмка" (варианто-независимые) ---
$commonDates = @('-d1st','12.12.2020','-d1end','17.12.2020','-d2st','10.12.2020','-d2end','15.12.2020')

# Пример "Успешный запуск" из документа использует N=4. Для варианта 2
# (функция Аккермана) N>=4 превышает практический предел вычислений,
# поэтому корректная программа выводит ERROR, а не результат.
$successLaunchKind    = if ($Variant -eq 2) { 'Error' } else { 'Success' }
$successLaunchDays    = if ($Variant -eq 2) { $null } else { 4 }
$successLaunchDisplay = if ($Variant -eq 2) { 'ERROR: ... (N=4 превышает предел для функции Аккермана)' } else { 'DAYS: 4; RESULT: <3 знака после запятой>' }

$acceptanceTests = @(
    [PSCustomObject]@{ Name = 'Запуск без аргументов'; Arguments = @(); Kind = 'Help'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'HELP: ...' },
    [PSCustomObject]@{ Name = 'Ввод числа вне диапазона [--task 3]'; Arguments = @('--task','3') + $commonDates; Kind = 'Error'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'ERROR: Unknown task. Task number must not exceed 2.' },
    [PSCustomObject]@{ Name = 'Ввод числа вне диапазона [--task 0]'; Arguments = @('--task','0') + $commonDates; Kind = 'Error'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'ERROR: Unknown task. Task number cannot be less than 1.' },
    [PSCustomObject]@{ Name = 'Ввод некорректного числа [--task one]'; Arguments = @('--task','one') + $commonDates; Kind = 'Error'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'ERROR: Task number must be an integer.' },
    [PSCustomObject]@{ Name = 'Ввод некорректного числа [--task 2.0]'; Arguments = @('--task','2.0') + $commonDates; Kind = 'Error'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'ERROR: Task number must be an integer.' },
    [PSCustomObject]@{ Name = 'Некорректное значение параметра [--task 2 -d1st 32.12.2020]'; Arguments = @('--task','2','-d1st','32.12.2020','-d1end','17.12.2020','-d2st','10.12.2020','-d2end','15.12.2020'); Kind = 'Error'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'ERROR: Value D1ST must be a valid date in format DD.MM.YYYY.' },
    [PSCustomObject]@{ Name = 'Обратный порядок дат в отрезке [--task 2]'; Arguments = @('--task','2','-d1st','17.12.2020','-d1end','12.12.2020','-d2st','10.12.2020','-d2end','15.12.2020'); Kind = 'Error'; ExpectedDays = $null; ExpectedResult = $null; ExpectedDisplay = 'ERROR: End of the first segment must not be earlier than its start.' },
    [PSCustomObject]@{ Name = 'Успешный запуск'; Arguments = @('--task','2') + $commonDates; Kind = $successLaunchKind; ExpectedDays = $successLaunchDays; ExpectedResult = $null; ExpectedDisplay = $successLaunchDisplay }
)

# --- Контрольные примеры из CSV для указанного варианта ---
$csvTests = @()
foreach ($row in $csvRows) {
    if ([int]$row.'Вариант' -ne $Variant) { continue }

    $num = $row.'№'
    $resultText = ([string]$row.'Результат').Trim()
    $comment = ([string]$row.'Комментарий').Trim()
    $daysText = ([string]$row.'N').Trim()

    $kind = $null
    $expectedDays = $null
    $expectedResult = $null
    $expectedDisplay = $resultText

    if ($resultText -match '^ERROR') {
        $kind = 'Error'
    } elseif ($resultText -match '^RESULT\s*:\s*(.+)$') {
        $kind = 'Success'
        $expectedResult = $Matches[1].Trim()
        $expectedDisplay = "DAYS: $daysText; RESULT: $($expectedResult)"
        if ($daysText -ne '') { $expectedDays = [int]$daysText }
    } else {
        continue
    }

    $csvTests += [PSCustomObject]@{
        Name = "Контрольный список #$num. $resultText. $comment"
        Arguments = @('--task','2','-d1st',[string]$row.'Начало1','-d1end',[string]$row.'Конец1','-d2st',[string]$row.'Начало2','-d2end',[string]$row.'Конец2')
        Kind = $kind
        ExpectedDays = $expectedDays
        ExpectedResult = $expectedResult
        ExpectedDisplay = $expectedDisplay
    }
}

$allTests = @($acceptanceTests) + @($csvTests)

# --- Заголовок ---
Write-Line 'Parameters:'
Write-Line "ExePath: $resolvedExe"
Write-Line "Variant: $Variant"
Write-Line ''

# --- Выполнение ---
$statOk = 0
$statErr = 0
$statWarn = 0

foreach ($t in $allTests) {
    $status = Run-Test -Test $t -ExeFile $exeFile -ExePrefixArgs $exePrefixArgs -TimeoutSeconds $MaxTestRuntime -ExeDisplay $exeDisplay
    switch ($status) {
        'Ok'   { $statOk++ }
        'Err'  { $statErr++ }
        'Warn' { $statWarn++ }
    }
}

Write-Line ''
Write-Line "Итог: OK: $statOk, ERR: $statErr, WARN: $statWarn"

if ($statErr -gt 0) { exit 1 } else { exit 0 }



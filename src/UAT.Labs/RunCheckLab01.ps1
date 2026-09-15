<#
.SYNOPSIS
    Автоматическая проверка лабораторной работы Lab01 (калькулятор).

.DESCRIPTION
    Запускает студенческий исполняемый файл и проверяет его вывод согласно
    критериям приёмки из Labs/Lab01.md, а также контрольным примерам из
    Labs/Lab01_ControlValues.csv (только для указанного варианта).

    Кроссплатформенный (Windows / Linux / macOS): требуется только PowerShell
    (5.1 или 7+), дополнительные модули не нужны.

.PARAMETER ExePath
    Путь до исполняемого файла. По умолчанию - src\Labs\bin\Debug\net10.0\Labs.exe
    (с автоматическим поиском в src\Labs\bin, если файл не найден).

.PARAMETER Variant
    Номер варианта (1-15). Если не указан - запрашивается интерактивно.

.PARAMETER MaxTestRuntime
    Максимальное время одного запуска в секундах (по умолчанию 5).
    Зависание программы помечается как Warning, а не ошибка.

.EXAMPLE
    .\RunCheckLab01.ps1 -Variant 1

.EXAMPLE
    .\RunCheckLab01.ps1 -Variant 3 -ExePath D:\...\Labs.exe -MaxTestRuntime 10
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

    $ExpectedKind  = $Test.Kind
    $ExpectedValue = $Test.ExpectedValue

    $res = [PSCustomObject]@{
        Passed     = $false
        Comment    = ''
        ActualKind = 'None'
    }

    $first = Get-FirstSignificantLine -Text $Output
    if ($null -eq $first) {
        $res.Comment = 'Вывод программы пуст: нет ни одной значимой строки'
        return $res
    }

    if ($first -match '^\s*RESULT')    { $res.ActualKind = 'Result' }
    elseif ($first -match '^\s*HELP')  { $res.ActualKind = 'Help' }
    elseif ($first -match '^\s*ERROR') { $res.ActualKind = 'Error' }
    else                               { $res.ActualKind = 'Unknown' }

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
        'Result' {
            if ($res.ActualKind -ne 'Result') {
                $res.Comment = "Ожидался RESULT, а получено: '$first'"
                return $res
            }
            if ($first -notmatch '^\s*RESULT\s*:\s*(.+)$') {
                $res.Comment = "После RESULT ожидается знак ':' и числовое значение: '$first'"
                return $res
            }
            $value = $Matches[1].Trim()

            # Формат: ровно 3 знака после запятой, разделитель '.' или ','
            if ($value -notmatch '^[-+]?\d+[.,]\d{3}$') {
                $res.Comment = "Значение должно форматироваться до 3 знаков после запятой (например '3.000', а не '$value')"
                return $res
            }

            $actualNum = [decimal]($value -replace ',', '.')
            if (-not [string]::IsNullOrEmpty($ExpectedValue)) {
                $expectedNum = [decimal]($ExpectedValue -replace ',', '.')
                # Сравнение до 2 знаков после запятой, 3-й знак игнорируется (усечение)
                $a2 = [math]::Truncate($actualNum * 100)
                $e2 = [math]::Truncate($expectedNum * 100)
                if ($a2 -eq $e2) {
                    $res.Passed = $true
                } else {
                    $res.Comment = "Значение не совпадает с эталоном до 2 знаков: ожидалось {0:0.00}, получено {1:0.00}" -f $expectedNum, $actualNum
                }
            } else {
                $res.Passed = $true
            }
        }
    }

    return $res
}

# ===================== Основной поток =====================

$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$csvPath = [System.IO.Path]::Combine($repoRoot, 'Labs', 'Lab01_ControlValues.csv')
$defaultDir = [System.IO.Path]::Combine($repoRoot, 'src', 'Labs', 'bin', 'Debug', 'net10.0')

# --- Проверка варианта ---
if (-not $PSBoundParameters.ContainsKey('Variant')) {
    do {
        $answer = Read-Host 'Введите номер варианта (1-15)'
        if ($answer -match '^\d+$') { $Variant = [int]$answer } else { $Variant = 0 }
    } while ($Variant -lt 1 -or $Variant -gt 15)
}
if ($Variant -lt 1 -or $Variant -gt 15) {
    Write-Line "Ошибка: вариант должен быть целым числом от 1 до 15 (получено: $Variant)" -Color $ColorErr
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
$acceptanceTests = @(
    [PSCustomObject]@{ Name = 'Запуск без аргументов'; Arguments = @(); Kind = 'Help'; ExpectedValue = $null; ExpectedDisplay = 'HELP: ...' },
    [PSCustomObject]@{ Name = 'Ввод числа вне диапазона [--task 2]'; Arguments = @('--task','2','-x','1','-y','2','-z','-1'); Kind = 'Error'; ExpectedValue = $null; ExpectedDisplay = 'ERROR: Unknown task. Task number must not exceed 1.' },
    [PSCustomObject]@{ Name = 'Ввод числа вне диапазона [--task 0]'; Arguments = @('--task','0','-x','1','-y','2','-z','-1'); Kind = 'Error'; ExpectedValue = $null; ExpectedDisplay = 'ERROR: Unknown task. Task number cannot be less than 1.' },
    [PSCustomObject]@{ Name = 'Ввод некорректного числа [--task one]'; Arguments = @('--task','one','-x','1','-y','2','-z','-1'); Kind = 'Error'; ExpectedValue = $null; ExpectedDisplay = 'ERROR: Task number must be integer number.' },
    [PSCustomObject]@{ Name = 'Ввод некорректного числа [--task 1.0]'; Arguments = @('--task','1.0','-x','1','-y','2','-z','-1'); Kind = 'Error'; ExpectedValue = $null; ExpectedDisplay = 'ERROR: Task number must be an integer.' },
    [PSCustomObject]@{ Name = 'Некорректное значение параметра [--task 1 -x Zero]'; Arguments = @('--task','1','-x','Zero','-y','2','-z','3'); Kind = 'Error'; ExpectedValue = $null; ExpectedDisplay = 'ERROR: Value X must be an integer.' }
)

# --- Контрольные примеры из CSV для указанного варианта ---
$csvTests = @()
foreach ($row in $csvRows) {
    if ([int]$row.'Вариант' -ne $Variant) { continue }

    $num = $row.'№'
    $resultText = ([string]$row.'Результат').Trim()
    $comment = ([string]$row.'Комментарий').Trim()

    $kind = $null
    $expectedValue = $null
    $expectedDisplay = $resultText

    if ($resultText -match '^ERROR') {
        $kind = 'Error'
    } elseif ($resultText -match '^RESULT\s*:\s*(.+)$') {
        $kind = 'Result'
        $expectedValue = $Matches[1].Trim()
        $expectedDisplay = 'RESULT: ' + $expectedValue
    } else {
        continue
    }

    $csvTests += [PSCustomObject]@{
        Name = "Контрольный список #$num. $resultText. $comment"
        Arguments = @('--task','1','-x',[string]$row.X,'-y',[string]$row.Y,'-z',[string]$row.Z)
        Kind = $kind
        ExpectedValue = $expectedValue
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


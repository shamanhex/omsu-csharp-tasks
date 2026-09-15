<#
.SYNOPSIS
    Автоматическая проверка лабораторной работы Lab03 (работа со строками).

.DESCRIPTION
    Запускает студенческий исполняемый файл и проверяет его вывод согласно
    критериям приёмки из Labs/Lab03.md.

    В рамках Lab03 реализуется задание --task 3 — проверка двух строк:
        EQUAL       - посимвольное совпадение (с учётом регистра);
        NORMALIZED  - совпадение после нормализации (регистр, пробелы);
        REVERSED    - первая строка является перевёртышем второй;
        S1_* / S2_* - определение типа каждой строки (email / телефон / IP).
    Задания --task 1 и --task 2 реализованы в предыдущих лабораторных работах
    и должны продолжать работать, однако данная проверка фокусируется на
    задании --task 3.

    В отличие от Lab01/Lab02 у Lab03 нет файла контрольных примеров и нет
    варианта: критерии приёмки фиксированы в Labs/Lab03.md.

    Кроссплатформенный (Windows / Linux / macOS): требуется только PowerShell
    (5.1 или 7+), дополнительные модули не нужны.

.PARAMETER ExePath
    Путь до исполняемого файла. По умолчанию - src\Labs\bin\Debug\net10.0\Labs.exe
    (с автоматическим поиском в src\Labs\bin, если файл не найден).

.PARAMETER MaxTestRuntime
    Максимальное время одного запуска в секундах (по умолчанию 5).
    Зависание программы помечается как Warning, а не ошибка.

.EXAMPLE
    .\RunCheckLab03.ps1

.EXAMPLE
    .\RunCheckLab03.ps1 -ExePath D:\...\Labs.exe -MaxTestRuntime 10
#>

[CmdletBinding()]
param(
    [string]$ExePath,
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

    if ($first -match '^\s*EQUAL')     { $res.ActualKind = 'Success' }
    elseif ($first -match '^\s*HELP')  { $res.ActualKind = 'Help' }
    elseif ($first -match '^\s*ERROR') { $res.ActualKind = 'Error' }
    else                               { $res.ActualKind = 'Unknown' }

    switch ($Test.Kind) {
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
            if ($res.ActualKind -ne 'Success') {
                $res.Comment = "Ожидался успешный результат (первая строка должна начинаться с 'EQUAL'), а получено: '$first'"
                return $res
            }

            $expectedChecks = @(
                @{ Label = 'EQUAL';      Value = $Test.ExpectedEqual },
                @{ Label = 'NORMALIZED'; Value = $Test.ExpectedNormalized },
                @{ Label = 'REVERSED';   Value = $Test.ExpectedReversed },
                @{ Label = 'S1_EMAIL';   Value = $Test.ExpectedS1Email },
                @{ Label = 'S1_PHONE';   Value = $Test.ExpectedS1Phone },
                @{ Label = 'S1_IP';      Value = $Test.ExpectedS1Ip },
                @{ Label = 'S2_EMAIL';   Value = $Test.ExpectedS2Email },
                @{ Label = 'S2_PHONE';   Value = $Test.ExpectedS2Phone },
                @{ Label = 'S2_IP';      Value = $Test.ExpectedS2Ip }
            )

            if ($lines.Count -lt $expectedChecks.Count) {
                $res.Comment = "Ожидалось $($expectedChecks.Count) значимых строк вывода (EQUAL, NORMALIZED, REVERSED, S1_*, S2_*), а получено только $($lines.Count)"
                return $res
            }

            for ($i = 0; $i -lt $expectedChecks.Count; $i++) {
                $line  = $lines[$i]
                $label = $expectedChecks[$i].Label

                if ($line -notmatch '^\s*([A-Za-z0-9_]+)\s*:\s*(TRUE|FALSE)\s*$') {
                    $res.Comment = "Строка #$($i + 1) должна иметь вид '$label : TRUE|FALSE', а получено: '$line'"
                    return $res
                }
                if ($Matches[1] -ne $label) {
                    $res.Comment = "Строка #$($i + 1) должна иметь метку '$label', а получено: '$($Matches[1])'"
                    return $res
                }
                if ($Matches[2] -ne $expectedChecks[$i].Value) {
                    $res.Comment = "Проверка '$label' ожидалась '$($expectedChecks[$i].Value)', а получено '$($Matches[2])'"
                    return $res
                }
            }
            $res.Passed = $true
        }
    }

    return $res
}
function New-Lab03Test {
    param(
        [string]$Name,
        [string[]]$Arguments = @(),
        [string]$Kind,
        [string]$ExpectedEqual,
        [string]$ExpectedNormalized,
        [string]$ExpectedReversed,
        [string]$ExpectedS1Email,
        [string]$ExpectedS1Phone,
        [string]$ExpectedS1Ip,
        [string]$ExpectedS2Email,
        [string]$ExpectedS2Phone,
        [string]$ExpectedS2Ip,
        [string]$ExpectedDisplay
    )

    if ([string]::IsNullOrEmpty($ExpectedDisplay) -and $Kind -eq 'Success') {
        $ExpectedDisplay = "EQUAL: $ExpectedEqual; NORMALIZED: $ExpectedNormalized; REVERSED: $ExpectedReversed; " +
            "S1_EMAIL: $ExpectedS1Email; S1_PHONE: $ExpectedS1Phone; S1_IP: $ExpectedS1Ip; " +
            "S2_EMAIL: $ExpectedS2Email; S2_PHONE: $ExpectedS2Phone; S2_IP: $ExpectedS2Ip"
    }

    return [PSCustomObject]@{
        Name               = $Name
        Arguments          = $Arguments
        Kind               = $Kind
        ExpectedEqual      = $ExpectedEqual
        ExpectedNormalized = $ExpectedNormalized
        ExpectedReversed   = $ExpectedReversed
        ExpectedS1Email    = $ExpectedS1Email
        ExpectedS1Phone    = $ExpectedS1Phone
        ExpectedS1Ip       = $ExpectedS1Ip
        ExpectedS2Email    = $ExpectedS2Email
        ExpectedS2Phone    = $ExpectedS2Phone
        ExpectedS2Ip       = $ExpectedS2Ip
        ExpectedDisplay    = $ExpectedDisplay
    }
}

# ===================== Основной поток =====================

$repoRoot   = Split-Path -Parent (Split-Path -Parent $scriptDir)
$defaultDir = [System.IO.Path]::Combine($repoRoot, 'src', 'Labs', 'bin', 'Debug', 'net10.0')

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

# --- Проверки из раздела "Приёмка" ---
# Для успешного запуска ожидаемые значения задаются строками 'TRUE'/'FALSE'
# в порядке вывода: EQUAL, NORMALIZED, REVERSED, S1_EMAIL, S1_PHONE, S1_IP,
# S2_EMAIL, S2_PHONE, S2_IP.
$acceptanceTests = @(
    (New-Lab03Test -Name 'Запуск без аргументов' -Arguments @() -Kind 'Help' -ExpectedDisplay 'HELP: ...'),
    (New-Lab03Test -Name 'Ввод числа вне диапазона [--task 4]' -Arguments @('--task','4','-s1','abc','-s2','abc') -Kind 'Error' -ExpectedDisplay 'ERROR: Unknown task. Task number must not exceed 3.'),
    (New-Lab03Test -Name 'Ввод числа вне диапазона [--task 0]' -Arguments @('--task','0','-s1','abc','-s2','abc') -Kind 'Error' -ExpectedDisplay 'ERROR: Unknown task. Task number cannot be less than 1.'),
    (New-Lab03Test -Name 'Ввод некорректного числа [--task three]' -Arguments @('--task','three','-s1','abc','-s2','abc') -Kind 'Error' -ExpectedDisplay 'ERROR: Task number must be an integer.'),
    (New-Lab03Test -Name 'Ввод некорректного числа [--task 3.0]' -Arguments @('--task','3.0','-s1','abc','-s2','abc') -Kind 'Error' -ExpectedDisplay 'ERROR: Task number must be an integer.'),
    (New-Lab03Test -Name 'Отсутствие обязательного аргумента [-s2]' -Arguments @('--task','3','-s1','abc') -Kind 'Error' -ExpectedDisplay 'ERROR: Value S2 must be specified.'),
    (New-Lab03Test -Name 'Отсутствие обязательного аргумента [-s1]' -Arguments @('--task','3','-s2','abc') -Kind 'Error' -ExpectedDisplay 'ERROR: Value S1 must be specified.'),
    (New-Lab03Test -Name 'Успешный запуск: посимвольное совпадение' -Arguments @('--task','3','-s1','Hello, world!','-s2','Hello, world!') -Kind 'Success' -ExpectedEqual 'TRUE' -ExpectedNormalized 'TRUE' -ExpectedReversed 'FALSE' -ExpectedS1Email 'FALSE' -ExpectedS1Phone 'FALSE' -ExpectedS1Ip 'FALSE' -ExpectedS2Email 'FALSE' -ExpectedS2Phone 'FALSE' -ExpectedS2Ip 'FALSE'),
    (New-Lab03Test -Name 'Успешный запуск: совпадение после нормализации' -Arguments @('--task','3','-s1','  Hello   world  ','-s2','hello world') -Kind 'Success' -ExpectedEqual 'FALSE' -ExpectedNormalized 'TRUE' -ExpectedReversed 'FALSE' -ExpectedS1Email 'FALSE' -ExpectedS1Phone 'FALSE' -ExpectedS1Ip 'FALSE' -ExpectedS2Email 'FALSE' -ExpectedS2Phone 'FALSE' -ExpectedS2Ip 'FALSE'),
    (New-Lab03Test -Name 'Успешный запуск: перевёртыш' -Arguments @('--task','3','-s1','abc','-s2','cba') -Kind 'Success' -ExpectedEqual 'FALSE' -ExpectedNormalized 'FALSE' -ExpectedReversed 'TRUE' -ExpectedS1Email 'FALSE' -ExpectedS1Phone 'FALSE' -ExpectedS1Ip 'FALSE' -ExpectedS2Email 'FALSE' -ExpectedS2Phone 'FALSE' -ExpectedS2Ip 'FALSE'),
    (New-Lab03Test -Name 'Успешный запуск: проверка типов (email + IP)' -Arguments @('--task','3','-s1','test@example.com','-s2','192.168.0.1') -Kind 'Success' -ExpectedEqual 'FALSE' -ExpectedNormalized 'FALSE' -ExpectedReversed 'FALSE' -ExpectedS1Email 'TRUE' -ExpectedS1Phone 'FALSE' -ExpectedS1Ip 'FALSE' -ExpectedS2Email 'FALSE' -ExpectedS2Phone 'FALSE' -ExpectedS2Ip 'TRUE'),
    (New-Lab03Test -Name 'Успешный запуск: проверка типов (телефон)' -Arguments @('--task','3','-s1','123-456-7890','-s2','abc') -Kind 'Success' -ExpectedEqual 'FALSE' -ExpectedNormalized 'FALSE' -ExpectedReversed 'FALSE' -ExpectedS1Email 'FALSE' -ExpectedS1Phone 'TRUE' -ExpectedS1Ip 'FALSE' -ExpectedS2Email 'FALSE' -ExpectedS2Phone 'FALSE' -ExpectedS2Ip 'FALSE')
)

# --- Заголовок ---
Write-Line 'Parameters:'
Write-Line "ExePath: $resolvedExe"
Write-Line ''

# --- Выполнение ---
$statOk = 0
$statErr = 0
$statWarn = 0

foreach ($t in $acceptanceTests) {
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
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

$ColorOk   = [ConsoleColor]::Green
$ColorErr  = [ConsoleColor]::Red
$ColorWarn = [ConsoleColor]::Yellow

function Write-Line {
    param([Parameter(Position = 0)][string]$Text, [ConsoleColor]$Color)
    if ($PSBoundParameters.ContainsKey('Color')) {
        Write-Host $Text -ForegroundColor $Color
    } else {
        Write-Host $Text
    }
}

function Write-Block {
    param(
        [string]$Label,
        [string]$Text,
        [ConsoleColor]$Color,
        [int]$MaxLines = -1
    )
    $lines = @()
    if ($null -ne $Text -and $Text.Length -gt 0) {
        $lines = @($Text -split '\r?\n')
    }
    if ($lines.Count -eq 0) {
        Write-Host ("    ${Label}:") -ForegroundColor $Color
        return
    }
    $shown = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($MaxLines -ge 0 -and $shown -ge $MaxLines) {
            Write-Host '    ...' -ForegroundColor $Color
            break
        }
        if ($shown -eq 0) {
            Write-Host ("    ${Label}: " + $lines[$i]) -ForegroundColor $Color
        } else {
            Write-Host ('    ' + $lines[$i]) -ForegroundColor $Color
        }
        $shown++
    }
}

function Get-FirstSignificantLine {
    param([string]$Text)
    if ($null -eq $Text -or $Text.Length -eq 0) { return $null }
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '\S') { return $line }
    }
    return $null
}
function Test-StudentOutput {
    param(
        [string]$Output,
        [string]$ExpectedKind,
        [string]$ExpectedValue
    )

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

function Invoke-Program {
    param(
        [string]$File,
        [string[]]$Arguments,
        [int]$TimeoutSeconds
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    $result = [PSCustomObject]@{
        StdOut     = ''
        StdErr     = ''
        ExitCode   = $null
        TimedOut   = $false
        StartError = $null
    }

    try {
        [void]$proc.Start()
    } catch {
        $result.StartError = $_.Exception.Message
        return $result
    }

    try {
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()

        $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            $result.TimedOut = $true
            try { $proc.Kill() } catch {}
            try { [void]$proc.WaitForExit() } catch {}
        }

        $result.StdOut = $outTask.Result
        $result.StdErr = $errTask.Result
        $result.ExitCode = $proc.ExitCode
    } catch {
        # ошибка чтения потоков не критична - частичный вывод уже собран
    } finally {
        try { $proc.Dispose() } catch {}
    }

    return $result
}
function Get-DisplayPath {
    param([string]$Path, [string]$RepoRoot)
    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $full.Substring($root.Length).TrimStart('\', '/')
        $dot = if ($env:OS -eq 'Windows_NT') { '.\' } else { './' }
        return $dot + $rel
    }
    return $full
}

function Format-CmdLine {
    param([string]$ExeDisplay, [string[]]$Arguments)
    if ($null -eq $Arguments -or $Arguments.Count -eq 0) {
        return $ExeDisplay
    }
    return $ExeDisplay + ' ' + ($Arguments -join ' ')
}

function Resolve-ExePath {
    param([string]$ProvidedPath, [string]$RepoRoot)

    $exeNames = @('Labs.exe', 'Labs', 'Lab.exe', 'Lab', 'Labs.dll', 'Lab.dll')

    $candidates = @()
    if (-not [string]::IsNullOrEmpty($ProvidedPath)) {
        $candidates += $ProvidedPath
    }

    $defaultDir = [System.IO.Path]::Combine($RepoRoot, 'src', 'Labs', 'bin', 'Debug', 'net10.0')
    foreach ($n in $exeNames) {
        $candidates += [System.IO.Path]::Combine($defaultDir, $n)
    }

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($c)
        }
    }

    # Широкий поиск по bin (иная конфигурация/фреймворк или имя exe)
    $binDir = [System.IO.Path]::Combine($RepoRoot, 'src', 'Labs', 'bin')
    if (Test-Path -LiteralPath $binDir) {
        $matches = @(Get-ChildItem -LiteralPath $binDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $exeNames -contains $_.Name })
        if ($matches.Count -gt 0) {
            $preferred = @($matches | Where-Object { $_.FullName -match 'Debug' -and $_.FullName -match 'net10' })
            if ($preferred.Count -gt 0) { return $preferred[0].FullName }
            return $matches[0].FullName
        }
    }

    return $null
}
function Run-Test {
    param(
        [object]$Test,
        [string]$ExeFile,
        [string[]]$ExePrefixArgs,
        [int]$TimeoutSeconds,
        [string]$ExeDisplay
    )

    $fullArgs = @()
    if ($ExePrefixArgs -and $ExePrefixArgs.Count -gt 0) {
        $fullArgs += $ExePrefixArgs
    }
    $fullArgs += @($Test.Arguments)

    $cmdDisplay = Format-CmdLine -ExeDisplay $ExeDisplay -Arguments @($Test.Arguments)

    $run = Invoke-Program -File $ExeFile -Arguments $fullArgs -TimeoutSeconds $TimeoutSeconds

    if ($run.StartError) {
        Write-Line "TEST [ERR]: $($Test.Name)" -Color $ColorErr
        Write-Line "    CMD: $cmdDisplay"
        Write-Line "    ERROR: не удалось запустить программу: $($run.StartError)" -Color $ColorErr
        return 'Err'
    }

    if ($run.TimedOut) {
        Write-Line "TEST [WARN]: $($Test.Name)" -Color $ColorWarn
        Write-Line "    CMD: $cmdDisplay"
        Write-Line "    WARNING: программа не завершилась за ${TimeoutSeconds} сек (возможно, ожидание 'Press any key...' или зависание)" -Color $ColorWarn
        $combined = $run.StdOut + $run.StdErr
        if ($combined -match '\S') {
            Write-Block -Label 'OUTPUT (частично)' -Text $combined -Color $ColorWarn -MaxLines 5
        }
        return 'Warn'
    }

    $output = $run.StdOut
    if (-not ($output -match '\S')) { $output = $run.StdErr }

    $analysis = Test-StudentOutput -Output $output -ExpectedKind $Test.Kind -ExpectedValue $Test.ExpectedValue

    if ($analysis.Passed) {
        Write-Line "TEST [OK]: $($Test.Name)" -Color $ColorOk
        Write-Line "    CMD: $cmdDisplay"
        Write-Block -Label 'OUTPUT' -Text $output -Color $ColorOk -MaxLines 5
        return 'Ok'
    }

    Write-Line "TEST [ERR]: $($Test.Name)" -Color $ColorErr
    Write-Line "    CMD: $cmdDisplay"
    Write-Block -Label 'ACTUAL' -Text $output -Color $ColorErr -MaxLines -1
    if ($null -ne $run.ExitCode -and $run.ExitCode -ne 0) {
        Write-Line "    EXIT CODE: $($run.ExitCode)"
    }
    Write-Line "    EXPECTED: $($Test.ExpectedDisplay)"
    Write-Line "    COMMENT: $($analysis.Comment)"
    return 'Err'
}
# ===================== Основной поток =====================

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
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
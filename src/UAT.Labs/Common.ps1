<#
.SYNOPSIS
    Общие вспомогательные функции для скриптов автоматической проверки
    лабораторных работ (RunCheckLab*.ps1).

.DESCRIPTION
    Переиспользуемые функции, не зависящие от конкретной лабораторной работы:
    запуск процесса с таймаутом, поиск исполняемого файла, форматирование вывода
    тестов и пр. Подключается через dot-sourcing:

        . (Join-Path $PSScriptRoot 'Common.ps1')

    Скрипт конкретной лабораторной работы после подключения определяет
    собственную функцию Test-StudentOutput, которая выполняет
    лабораторно-специфичный анализ вывода программы.

    Соглашение о структуре объекта теста ($Test), передаваемого в Run-Test и
    Test-StudentOutput:
        Name            - название теста
        Arguments       - массив аргументов командной строки
        Kind            - тип ожидаемого результата: 'Help' | 'Error' | 'Success' | 'Result'
        ExpectedDisplay - текст эталона для вывода при ошибке
        ... и лабораторно-специфичные поля эталона (например, ExpectedValue
            для Lab01 или ExpectedDays/ExpectedResult для Lab02).

    Кроссплатформенный (Windows / Linux / macOS): требуется только PowerShell
    (5.1 или 7+), дополнительные модули не нужны.
#>

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

    $analysis = Test-StudentOutput -Output $output -Test $Test

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


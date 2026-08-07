param(
    [string]$CuePath,
    [string]$Mingw,
    [switch]$ResolveCueOnly,
    [switch]$InstallDependencies,
    [switch]$NoInstallDependencies,
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
$Kit = $PSScriptRoot
$Framework = Join-Path $Kit "psxrecomp-src"
$FrameworkTag = "kit/sf2-20260807"
$FrameworkRef = "452cc0c06ec9fb93f28c5848960f7564c76a1ea8"
$RecompUi = Join-Path $Kit "recomp-ui"
$RecompUiTag = "kit/sf2-20260807"
$RecompUiRef = "514c9e29f6d043867cea2fe91ca3cca24c69477e"
$InputDir = Join-Path $Kit "input"
$GeneratedDir = Join-Path $Kit "generated"
$BuildDir = Join-Path $Kit "out\release"
$SetupLog = Join-Path $Kit "setup.log"
$TranscriptStarted = $false

function Refresh-ProcessPath {
    $MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = "$MachinePath;$UserPath"
}

function Find-Application {
    param([string]$Name, [string[]]$Candidates = @())

    $Command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($Command) { return $Command.Source }
    if ($env:SF2_SETUP_DISABLE_STANDARD_DISCOVERY -eq "1") { return $null }

    foreach ($Pattern in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($Pattern)) { continue }
        $Match = Get-ChildItem -Path $Pattern -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($Match) { return $Match.FullName }
    }
    return $null
}

function Test-PythonCandidate {
    param([string]$File, [string[]]$Prefix = @())

    if ([string]::IsNullOrWhiteSpace($File)) { return $null }
    try {
        & $File @Prefix -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" *> $null
        if ($LASTEXITCODE -eq 0) {
            return [pscustomobject]@{ File = $File; Prefix = @($Prefix) }
        }
    } catch {
        return $null
    }
    return $null
}

function Find-Python {
    $PythonCommand = Get-Command python -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($PythonCommand -and $PythonCommand.Source -notmatch '(?i)\\WindowsApps\\python(?:3)?\.exe$') {
        $Result = Test-PythonCandidate $PythonCommand.Source
        if ($Result) { return $Result }
    }

    $PyCommand = Get-Command py -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($PyCommand) {
        $Result = Test-PythonCandidate $PyCommand.Source @("-3")
        if ($Result) { return $Result }
    }

    if ($env:SF2_SETUP_DISABLE_STANDARD_DISCOVERY -ne "1") {
        $Candidates = @(
            "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe",
            "$env:ProgramFiles\Python*\python.exe",
            "${env:ProgramFiles(x86)}\Python*\python.exe"
        )
        foreach ($Pattern in $Candidates) {
            if ([string]::IsNullOrWhiteSpace($Pattern)) { continue }
            foreach ($Candidate in @(Get-ChildItem -Path $Pattern -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending)) {
                $Result = Test-PythonCandidate $Candidate.FullName
                if ($Result) { return $Result }
            }
        }
    }
    return $null
}

function Find-MingwToolchain {
    param([string]$RequestedRoot)

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $Root = [IO.Path]::GetFullPath($RequestedRoot)
        $Gcc = Join-Path $Root "bin\gcc.exe"
        $Gxx = Join-Path $Root "bin\g++.exe"
        $Ninja = Join-Path $Root "bin\ninja.exe"
        if ((Test-Path -LiteralPath $Gcc) -and (Test-Path -LiteralPath $Gxx) -and
            (Test-Path -LiteralPath $Ninja)) {
            return [pscustomobject]@{ Root = $Root; Gcc = $Gcc; Gxx = $Gxx; Ninja = $Ninja }
        }
        return $null
    }

    $PathGcc = Get-Command gcc -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $PathGxx = Get-Command g++ -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $PathNinja = Get-Command ninja -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($PathGcc -and $PathGxx -and $PathNinja -and
        (Split-Path $PathGcc.Source -Parent) -eq (Split-Path $PathGxx.Source -Parent) -and
        (Split-Path $PathGcc.Source -Parent) -eq (Split-Path $PathNinja.Source -Parent)) {
        return [pscustomobject]@{
            Root = Split-Path (Split-Path $PathGcc.Source -Parent) -Parent
            Gcc = $PathGcc.Source
            Gxx = $PathGxx.Source
            Ninja = $PathNinja.Source
        }
    }

    if ($env:SF2_SETUP_DISABLE_STANDARD_DISCOVERY -eq "1") { return $null }
    $Roots = @(
        "C:\msys64\mingw64",
        "C:\mingw64"
    )
    if ($env:LOCALAPPDATA) {
        $Roots += @(Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.*" -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "mingw64" })
    }
    foreach ($Root in $Roots) {
        $Gcc = Join-Path $Root "bin\gcc.exe"
        $Gxx = Join-Path $Root "bin\g++.exe"
        $Ninja = Join-Path $Root "bin\ninja.exe"
        if ((Test-Path -LiteralPath $Gcc) -and (Test-Path -LiteralPath $Gxx) -and
            (Test-Path -LiteralPath $Ninja)) {
            return [pscustomobject]@{ Root = $Root; Gcc = $Gcc; Gxx = $Gxx; Ninja = $Ninja }
        }
    }
    return $null
}

function Resolve-SetupTools {
    param([string]$RequestedMingw)

    $Git = Find-Application "git" @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    $CMake = Find-Application "cmake" @(
        "$env:ProgramFiles\CMake\bin\cmake.exe",
        "${env:ProgramFiles(x86)}\CMake\bin\cmake.exe",
        "$env:LOCALAPPDATA\Programs\CMake\bin\cmake.exe"
    )
    return [pscustomobject]@{
        Git = $Git
        Python = Find-Python
        CMake = $CMake
        Mingw = Find-MingwToolchain $RequestedMingw
    }
}

function Get-MissingToolNames {
    param($Tools)
    $Missing = @()
    if (-not $Tools.Git) { $Missing += "Git" }
    if (-not $Tools.Python) { $Missing += "Python 3.10+" }
    if (-not $Tools.CMake) { $Missing += "CMake" }
    if (-not $Tools.Mingw) { $Missing += "MinGW-w64 GCC + Ninja" }
    return $Missing
}

function Install-MissingTools {
    param($Tools)

    $Winget = Find-Application "winget"
    if (-not $Winget) {
        throw "Missing build tools and WinGet is unavailable. Install 'App Installer' from Microsoft, then run SETUP.bat again. Visual Studio is not required."
    }

    $Packages = @()
    if (-not $Tools.Git) { $Packages += [pscustomobject]@{ Id = "Git.Git"; Label = "Git" } }
    if (-not $Tools.Python) { $Packages += [pscustomobject]@{ Id = "Python.Python.3.13"; Label = "Python" } }
    if (-not $Tools.CMake) { $Packages += [pscustomobject]@{ Id = "Kitware.CMake"; Label = "CMake" } }
    if (-not $Tools.Mingw) { $Packages += [pscustomobject]@{ Id = "BrechtSanders.WinLibs.POSIX.UCRT"; Label = "MinGW-w64 GCC and Ninja" } }

    foreach ($Package in $Packages) {
        $Id = $Package.Id
        $Label = $Package.Label
        Write-Host "Installing $Label through WinGet ($Id)..." -ForegroundColor Cyan
        & $Winget install --id $Id --exact --silent --disable-interactivity `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "WinGet could not install $Label (exit $LASTEXITCODE). See setup.log, or install package '$Id' manually and rerun SETUP.bat."
        }
    }
    Refresh-ProcessPath
}

function Invoke-Python {
    param($Python, [string[]]$Arguments)
    $AllArguments = @($Python.Prefix) + $Arguments
    & $Python.File @AllArguments
}

function Assert-AsciiLauncherPath {
    param([string]$Path, [string]$Label)

    if ($Path -match '[^\x00-\x7F]') {
        throw "$Label contains characters that play.bat cannot safely represent: $Path. Move the extracted kit and both disc files to an ASCII-only path such as C:\Games\SF2, then run SETUP.bat again."
    }
}

function Checkout-PinnedTag {
    param([string]$Repository, [string]$Tag, [string]$ExpectedCommit, [string]$Label)

    $TagRef = "refs/tags/$Tag"
    & $Tools.Git -C $Repository fetch origin "+${TagRef}:${TagRef}"
    if ($LASTEXITCODE -ne 0) { throw "$Label tag fetch failed: $Tag" }
    & $Tools.Git -C $Repository checkout --detach $TagRef
    if ($LASTEXITCODE -ne 0) { throw "$Label checkout failed: $Tag" }
    $ActualCommit = (& $Tools.Git -C $Repository rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $ActualCommit -ne $ExpectedCommit) {
        throw "$Label tag resolved to unexpected commit: expected $ExpectedCommit, got $ActualCommit"
    }
}

function Show-ToolSummary {
    param($Tools)
    $PythonLabel = $Tools.Python.File
    if ($Tools.Python.Prefix.Count) { $PythonLabel += " " + ($Tools.Python.Prefix -join " ") }
    Write-Host "Build tools ready:" -ForegroundColor Green
    Write-Host "  Git:     $($Tools.Git)"
    Write-Host "  Python:  $PythonLabel"
    Write-Host "  CMake:   $($Tools.CMake)"
    Write-Host "  GCC:     $($Tools.Mingw.Gcc)"
    Write-Host "  Ninja:   $($Tools.Mingw.Ninja)"
    Write-Host "  Visual Studio is not required."
}

if (-not $ResolveCueOnly) {
    try {
        Start-Transcript -LiteralPath $SetupLog -Append | Out-Null
        $TranscriptStarted = $true
        Write-Host "Syphon Filter 2 Recompiled setup" -ForegroundColor Cyan
        Write-Host "A complete log is written to: $SetupLog"
    } catch {
        $TranscriptStarted = $false
    }
}

trap {
    Write-Host ""
    Write-Host "SETUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Review setup.log, redact personal paths, and attach it if the message above is not enough."
    if ($TranscriptStarted) { Stop-Transcript | Out-Null }
    exit 1
}

if ($PreflightOnly) {
    $Tools = Resolve-SetupTools $Mingw
    $Missing = @(Get-MissingToolNames $Tools)
    if ($Missing.Count -and -not $NoInstallDependencies) {
        if ($InstallDependencies) {
            Install-MissingTools $Tools
        } else {
            $Reply = Read-Host "Missing $($Missing -join ', '). Install automatically with WinGet? [Y/n]"
            if ([string]::IsNullOrWhiteSpace($Reply) -or $Reply -match '^(?i)y(?:es)?$') {
                Install-MissingTools $Tools
            }
        }
        $Tools = Resolve-SetupTools $Mingw
        $Missing = @(Get-MissingToolNames $Tools)
    }
    if ($Missing.Count) {
        throw "Missing: $($Missing -join ', '). Run SETUP.bat for automatic installation, or install the listed tools and rerun."
    }
    Show-ToolSummary $Tools
    if ($TranscriptStarted) { Stop-Transcript | Out-Null }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($CuePath)) {
    $AllCues = @(Get-ChildItem -LiteralPath $Kit -File -Filter "*.cue")
    $Disc1Cues = @($AllCues | Where-Object { $_.BaseName -match '(?i)disc\s*1' })
    if ($Disc1Cues.Count -eq 1) {
        $CuePath = $Disc1Cues[0].FullName
    } elseif ($AllCues.Count -eq 1) {
        $CuePath = $AllCues[0].FullName
    } else {
        $Found = if ($AllCues.Count) {
            ($AllCues.FullName | ForEach-Object { "  $_" }) -join [Environment]::NewLine
        } else {
            "  (none)"
        }
        throw "Could not uniquely find Disc 1 beside SETUP.ps1. Found:`n$Found`nRun SETUP.ps1 -CuePath <Disc 1.cue> to choose it explicitly."
    }
    Write-Host "Auto-detected Disc 1: $CuePath"
}
if (-not (Test-Path -LiteralPath $CuePath -PathType Leaf)) {
    throw "Disc 1 CUE not found: $CuePath"
}
$CuePath = (Resolve-Path -LiteralPath $CuePath).Path
if ($ResolveCueOnly) {
    Write-Output $CuePath
    exit 0
}

# play.bat is deliberately ASCII+CRLF for cmd.exe compatibility. Reject paths
# that would otherwise be silently replaced with '?' before doing a long build.
Assert-AsciiLauncherPath $Kit "The extracted kit path"
Assert-AsciiLauncherPath $CuePath "The Disc 1 CUE path"

Write-Host "== 0/7 prepare build tools =="
$Tools = Resolve-SetupTools $Mingw
$Missing = @(Get-MissingToolNames $Tools)
if ($Missing.Count) {
    if ($NoInstallDependencies) {
        throw "Missing: $($Missing -join ', '). Run SETUP.bat for automatic installation, or install the listed tools and rerun."
    }
    if ($InstallDependencies) {
        Install-MissingTools $Tools
    } else {
        $Reply = Read-Host "Missing $($Missing -join ', '). Install automatically with WinGet? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($Reply) -or $Reply -match '^(?i)y(?:es)?$') {
            Install-MissingTools $Tools
        } else {
            throw "Setup cannot continue without $($Missing -join ', '). Visual Studio is not required."
        }
    }
    $Tools = Resolve-SetupTools $Mingw
    $Missing = @(Get-MissingToolNames $Tools)
    if ($Missing.Count) {
        throw "Installation completed but setup still cannot locate: $($Missing -join ', '). See setup.log."
    }
}
Show-ToolSummary $Tools

$env:PATH = "$(Split-Path $Tools.Mingw.Gcc -Parent);$(Split-Path $Tools.Git -Parent);$(Split-Path $Tools.CMake -Parent);$env:PATH"

Write-Host "== 1/7 fetch pinned PSXRecomp source =="
if (-not (Test-Path -LiteralPath (Join-Path $Framework ".git"))) {
    & $Tools.Git clone --recurse-submodules https://github.com/Alexbeav/psxrecomp.git $Framework
    if ($LASTEXITCODE -ne 0) { throw "framework clone failed" }
}
Checkout-PinnedTag $Framework $FrameworkTag $FrameworkRef "framework"
& $Tools.Git -C $Framework submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "framework submodule update failed" }

Write-Host "== 2/7 fetch pinned PSXRecomp launcher =="
if (-not (Test-Path -LiteralPath (Join-Path $RecompUi ".git"))) {
    & $Tools.Git clone --recurse-submodules https://github.com/Alexbeav/recomp-ui.git $RecompUi
    if ($LASTEXITCODE -ne 0) { throw "recomp-ui clone failed" }
}
Checkout-PinnedTag $RecompUi $RecompUiTag $RecompUiRef "recomp-ui"
& $Tools.Git -C $RecompUi submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "recomp-ui submodule update failed" }

Write-Host "== 3/7 extract and verify SCUS_944.51 from your Disc 1 =="
$PythonPackages = Join-Path $Kit "out\setup-python"
if (-not (Test-Path -LiteralPath (Join-Path $PythonPackages "pycdlib"))) {
    New-Item -ItemType Directory -Force $PythonPackages | Out-Null
    Invoke-Python $Tools.Python @("-m", "pip", "install", "--quiet", "--disable-pip-version-check", "--target", $PythonPackages, "pycdlib==1.16.0")
    if ($LASTEXITCODE -ne 0) {
        Invoke-Python $Tools.Python @("-m", "ensurepip", "--upgrade")
        if ($LASTEXITCODE -ne 0) { throw "Python pip bootstrap failed" }
        Invoke-Python $Tools.Python @("-m", "pip", "install", "--quiet", "--disable-pip-version-check", "--target", $PythonPackages, "pycdlib==1.16.0")
        if ($LASTEXITCODE -ne 0) { throw "local pycdlib installation failed" }
    }
}
$PreviousPythonPath = $env:PYTHONPATH
$env:PYTHONPATH = if ($PreviousPythonPath) { "$PythonPackages;$PreviousPythonPath" } else { $PythonPackages }
New-Item -ItemType Directory -Force $InputDir | Out-Null
Invoke-Python $Tools.Python @((Join-Path $Kit "extract_boot_exe.py"), $CuePath, $InputDir)
if ($LASTEXITCODE -gt 1) { throw "boot executable extraction failed" }
if ($LASTEXITCODE -eq 1) {
    throw "unsupported SCUS_944.51 revision; see the hash warning above"
}

Write-Host "== 4/7 regenerate the MIT-licensed OpenBIOS backend =="
New-Item -ItemType Directory -Force (Join-Path $Framework "generated") | Out-Null
$BiosTool = Join-Path $Kit "psxrecomp-cli\libexec\psxrecomp-bios.exe"
Push-Location $Framework
try {
    & $BiosTool --config bios/OpenBIOS.toml
    if ($LASTEXITCODE -ne 0) { throw "BIOS recompilation failed" }
} finally {
    Pop-Location
}

Write-Host "== 5/7 recompile the resident game executable =="
$GameTool = Join-Path $Kit "psxrecomp-cli\libexec\psxrecomp-game.exe"
Push-Location $Kit
try {
    & $GameTool --config game.toml
    if ($LASTEXITCODE -ne 0) { throw "game recompilation failed" }
} finally {
    Pop-Location
}

Write-Host "== 6/7 build the native runtime and PSXRecomp launcher =="
& $Tools.CMake -S $Kit -B $BuildDir -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_C_COMPILER=$($Tools.Mingw.Gcc -replace '\\','/')" `
    "-DCMAKE_CXX_COMPILER=$($Tools.Mingw.Gxx -replace '\\','/')" `
    "-DCMAKE_MAKE_PROGRAM=$($Tools.Mingw.Ninja -replace '\\','/')" `
    "-DPSXRECOMP_ROOT=$($Framework -replace '\\','/')" `
    "-DRECOMP_UI_ROOT=$($RecompUi -replace '\\','/')" `
    -DPSX_DEBUG_TOOLS=ON `
    -DPSX_RECOMP_UI=ON
if ($LASTEXITCODE -ne 0) { throw "runtime configuration failed" }
& $Tools.CMake --build $BuildDir --target psx-runtime --parallel
if ($LASTEXITCODE -ne 0) { throw "runtime build failed" }

Write-Host "== 7/7 stage private inputs and write launcher =="
$BuildSaves = Join-Path $BuildDir "saves"
New-Item -ItemType Directory -Force $BuildSaves | Out-Null
Copy-Item -LiteralPath (Join-Path $Kit "settings.toml") -Destination $BuildDir -Force
Copy-Item -LiteralPath (Join-Path $Kit "keybinds.ini") -Destination $BuildDir -Force

$Exe = Join-Path $BuildDir "SyphonFilter2Recompiled.exe"
if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
    throw "built runtime not found: $Exe"
}
$Cue = $CuePath
$Config = Join-Path $Kit "game.toml"
$Launcher = Join-Path $Kit "play.bat"
$LauncherText = @"
@echo off
set "PSX_OVERLAY_AUTOCOMPILE_OFF=1"
set "PSX_NATIVE_RANK_LIMIT=0"
cd /d "$BuildDir"
start "Syphon Filter 2 Recompiled" "$Exe" --game "$Config" --disc "$Cue" --memcard-dir "$BuildSaves" --launcher
"@
$LauncherText = ($LauncherText -replace "`r?`n", "`r`n")
[IO.File]::WriteAllText($Launcher, $LauncherText, [Text.Encoding]::ASCII)

Write-Host ""
Write-Host "Setup complete. Run play.bat to open the PSXRecomp launcher." -ForegroundColor Green
Write-Host "Private generated files remain only inside this extracted kit."
if ($TranscriptStarted) { Stop-Transcript | Out-Null }

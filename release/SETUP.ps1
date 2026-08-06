param(
    [string]$CuePath,
    [string]$Mingw,
    [switch]$ResolveCueOnly
)

$ErrorActionPreference = "Stop"
$Kit = $PSScriptRoot
$Framework = Join-Path $Kit "psxrecomp-src"
$FrameworkRef = "452cc0c06ec9fb93f28c5848960f7564c76a1ea8"
$RecompUi = Join-Path $Kit "recomp-ui"
$RecompUiRef = "514c9e29f6d043867cea2fe91ca3cca24c69477e"
$InputDir = Join-Path $Kit "input"
$GeneratedDir = Join-Path $Kit "generated"
$BuildDir = Join-Path $Kit "out\release"

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
foreach ($Tool in @("git", "python", "cmake")) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        throw "Required tool is not on PATH: $Tool"
    }
}
if ([string]::IsNullOrWhiteSpace($Mingw)) {
    $PathGcc = Get-Command gcc -ErrorAction SilentlyContinue
    $PathNinja = Get-Command ninja -ErrorAction SilentlyContinue
    if ($PathGcc -and $PathNinja -and
        (Split-Path $PathGcc.Source -Parent) -eq (Split-Path $PathNinja.Source -Parent)) {
        $Mingw = Split-Path (Split-Path $PathGcc.Source -Parent) -Parent
    } elseif ((Test-Path -LiteralPath "C:\msys64\mingw64\bin\gcc.exe") -and
              (Test-Path -LiteralPath "C:\msys64\mingw64\bin\ninja.exe")) {
        $Mingw = "C:\msys64\mingw64"
    } else {
        throw "MinGW64 gcc and Ninja were not found on PATH or under C:\msys64\mingw64. Install WinLibs/MSYS2, or pass -Mingw <mingw64 folder>."
    }
    Write-Host "Auto-detected MinGW toolchain: $Mingw"
}
$Ninja = Join-Path $Mingw "bin\ninja.exe"
$Gcc = Join-Path $Mingw "bin\gcc.exe"
if (-not (Test-Path -LiteralPath $Ninja) -or -not (Test-Path -LiteralPath $Gcc)) {
    throw "MSYS2 MinGW64 gcc/ninja not found under $Mingw"
}

Write-Host "== 1/7 fetch pinned PSXRecomp source =="
if (-not (Test-Path -LiteralPath (Join-Path $Framework ".git"))) {
    git clone --recurse-submodules https://github.com/Alexbeav/psxrecomp.git $Framework
    if ($LASTEXITCODE -ne 0) { throw "framework clone failed" }
}
git -C $Framework fetch origin $FrameworkRef
if ($LASTEXITCODE -ne 0) { throw "framework fetch failed" }
git -C $Framework checkout --detach $FrameworkRef
if ($LASTEXITCODE -ne 0) { throw "framework checkout failed" }
git -C $Framework submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "framework submodule update failed" }

Write-Host "== 2/7 fetch pinned PSXRecomp launcher =="
if (-not (Test-Path -LiteralPath (Join-Path $RecompUi ".git"))) {
    git clone --recurse-submodules https://github.com/Alexbeav/recomp-ui.git $RecompUi
    if ($LASTEXITCODE -ne 0) { throw "recomp-ui clone failed" }
}
git -C $RecompUi fetch origin $RecompUiRef
if ($LASTEXITCODE -ne 0) { throw "recomp-ui fetch failed" }
git -C $RecompUi checkout --detach $RecompUiRef
if ($LASTEXITCODE -ne 0) { throw "recomp-ui checkout failed" }
git -C $RecompUi submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "recomp-ui submodule update failed" }

Write-Host "== 3/7 extract and verify SCUS_944.51 from your Disc 1 =="
python -m pip install --quiet pycdlib
if ($LASTEXITCODE -ne 0) { throw "pycdlib installation failed" }
New-Item -ItemType Directory -Force $InputDir | Out-Null
python (Join-Path $Kit "extract_boot_exe.py") $CuePath $InputDir
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
$env:PATH = "$(Join-Path $Mingw 'bin');$env:PATH"
cmake -S $Kit -B $BuildDir -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    "-DPSXRECOMP_ROOT=$($Framework -replace '\\','/')" `
    "-DRECOMP_UI_ROOT=$($RecompUi -replace '\\','/')" `
    -DPSX_DEBUG_TOOLS=ON `
    -DPSX_RECOMP_UI=ON
if ($LASTEXITCODE -ne 0) { throw "runtime configuration failed" }
cmake --build $BuildDir --target psx-runtime --parallel
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
@"
@echo off
set "PSX_OVERLAY_AUTOCOMPILE_OFF=1"
set "PSX_NATIVE_RANK_LIMIT=0"
cd /d "$BuildDir"
start "Syphon Filter 2 Recompiled" "$Exe" --game "$Config" --disc "$Cue" --memcard-dir "$BuildSaves" --launcher
"@ | Set-Content -LiteralPath $Launcher -Encoding ascii

Write-Host ""
Write-Host "Setup complete. Run play.bat to open the PSXRecomp launcher."
Write-Host "Private generated files remain only inside this extracted kit."

param(
    [Parameter(Mandatory = $true)] [string]$CuePath,
    [string]$Mingw = "C:\msys64\mingw64"
)

$ErrorActionPreference = "Stop"
$Kit = $PSScriptRoot
$Framework = Join-Path $Kit "psxrecomp-src"
$FrameworkRef = "34dcc23dd51005bd5a3c1b399ea2189e9e9b4f7e"
$InputDir = Join-Path $Kit "input"
$GeneratedDir = Join-Path $Kit "generated"
$BuildDir = Join-Path $Kit "out\release"

if (-not (Test-Path -LiteralPath $CuePath -PathType Leaf)) {
    throw "Disc 1 CUE not found: $CuePath"
}
foreach ($Tool in @("git", "python", "cmake")) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        throw "Required tool is not on PATH: $Tool"
    }
}
$Ninja = Join-Path $Mingw "bin\ninja.exe"
$Gcc = Join-Path $Mingw "bin\gcc.exe"
if (-not (Test-Path -LiteralPath $Ninja) -or -not (Test-Path -LiteralPath $Gcc)) {
    throw "MSYS2 MinGW64 gcc/ninja not found under $Mingw"
}

Write-Host "== 1/6 fetch pinned PSXRecomp source =="
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

Write-Host "== 2/6 extract and verify SCUS_944.51 from your Disc 1 =="
python -m pip install --quiet pycdlib
if ($LASTEXITCODE -ne 0) { throw "pycdlib installation failed" }
New-Item -ItemType Directory -Force $InputDir | Out-Null
python (Join-Path $Kit "extract_boot_exe.py") $CuePath $InputDir
if ($LASTEXITCODE -gt 1) { throw "boot executable extraction failed" }
if ($LASTEXITCODE -eq 1) {
    throw "unsupported SCUS_944.51 revision; see the hash warning above"
}

Write-Host "== 3/6 regenerate the MIT-licensed OpenBIOS backend =="
New-Item -ItemType Directory -Force (Join-Path $Framework "generated") | Out-Null
$BiosTool = Join-Path $Kit "psxrecomp-cli\libexec\psxrecomp-bios.exe"
Push-Location $Framework
try {
    & $BiosTool --config bios/OpenBIOS.toml
    if ($LASTEXITCODE -ne 0) { throw "BIOS recompilation failed" }
} finally {
    Pop-Location
}

Write-Host "== 4/6 recompile the resident game executable =="
$GameTool = Join-Path $Kit "psxrecomp-cli\libexec\psxrecomp-game.exe"
Push-Location $Kit
try {
    & $GameTool --config game.toml
    if ($LASTEXITCODE -ne 0) { throw "game recompilation failed" }
} finally {
    Pop-Location
}

Write-Host "== 5/6 build the native runtime =="
$env:PATH = "$(Join-Path $Mingw 'bin');$env:PATH"
cmake -S $Kit -B $BuildDir -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    "-DPSXRECOMP_ROOT=$($Framework -replace '\\','/')" `
    -DPSX_DEBUG_TOOLS=ON `
    -DPSX_RECOMP_UI=OFF
if ($LASTEXITCODE -ne 0) { throw "runtime configuration failed" }
cmake --build $BuildDir --target psx-runtime --parallel
if ($LASTEXITCODE -ne 0) { throw "runtime build failed" }

Write-Host "== 6/6 stage private inputs and write launcher =="
$BuildSaves = Join-Path $BuildDir "saves"
New-Item -ItemType Directory -Force $BuildSaves | Out-Null
Copy-Item -LiteralPath (Join-Path $Kit "settings.toml") -Destination $BuildDir -Force
Copy-Item -LiteralPath (Join-Path $Kit "keybinds.ini") -Destination $BuildDir -Force

$Exe = Join-Path $BuildDir "SyphonFilter2Recompiled.exe"
if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
    throw "built runtime not found: $Exe"
}
$Cue = (Resolve-Path -LiteralPath $CuePath).Path
$Config = Join-Path $Kit "game.toml"
$Launcher = Join-Path $Kit "play.bat"
@"
@echo off
set "PSX_OVERLAY_AUTOCOMPILE=0"
set "PSX_NATIVE_RANK_LIMIT=0"
cd /d "$BuildDir"
start "Syphon Filter 2 Recompiled" "$Exe" --game "$Config" --disc "$Cue" --memcard-dir "$BuildSaves" --no-launcher
"@ | Set-Content -LiteralPath $Launcher -Encoding ascii

Write-Host ""
Write-Host "Setup complete. Run: $Launcher"
Write-Host "Private generated files remain only inside this extracted kit."

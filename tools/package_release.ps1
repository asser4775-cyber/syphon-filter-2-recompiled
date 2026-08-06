param(
    [string]$Version = "v0.1.0-alpha",
    [string]$BuildDir = "build-release",
    [string]$ExpectedExeSha256 = ""
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Build = Resolve-Path (Join-Path $Root $BuildDir)
$SourceExe = Join-Path $Build "SyphonFilter2Recompiled.exe"
if (-not (Test-Path -LiteralPath $SourceExe -PathType Leaf)) {
    # The accepted lab build predates the public output name.
    $SourceExe = Join-Path $Build "SCUS94451_Recompiled.exe"
}
if (-not (Test-Path -LiteralPath $SourceExe -PathType Leaf)) {
    throw "Built executable not found under $Build"
}

$ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $SourceExe).Hash
if ($ExpectedExeSha256 -and $ActualHash -ne $ExpectedExeSha256.ToUpperInvariant()) {
    throw "Executable SHA-256 mismatch: expected $ExpectedExeSha256, got $ActualHash"
}

$StageRoot = Join-Path $Root "release-stage"
$Stage = Join-Path $StageRoot "syphon-filter-2-recompiled-$Version-windows-x64"
$Dist = Join-Path $Root "dist"
$Zip = Join-Path $Dist "syphon-filter-2-recompiled-$Version-windows-x64.zip"
if (Test-Path -LiteralPath $StageRoot) {
    Remove-Item -LiteralPath $StageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Stage,(Join-Path $Stage "bios"),$Dist | Out-Null

Copy-Item -LiteralPath $SourceExe -Destination (Join-Path $Stage "SyphonFilter2Recompiled.exe")
foreach ($Name in @("README.md", "LICENSE", "RELEASE_NOTES.md", "game.toml", "settings.toml", "keybinds.ini")) {
    Copy-Item -LiteralPath (Join-Path $Root $Name) -Destination $Stage
}
Copy-Item -LiteralPath (Join-Path $Root "packaging/release/START_HERE.txt") -Destination $Stage

$BiosDir = Join-Path $Build "bios"
foreach ($Name in @("openbios.bin", "OpenBIOS.LICENSE")) {
    $Source = Join-Path $BiosDir $Name
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required OpenBIOS release file missing: $Source"
    }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $Stage "bios/$Name")
}
if ((Get-Item -LiteralPath (Join-Path $Stage "bios/openbios.bin")).Length -ne 524288) {
    throw "Bundled OpenBIOS must be exactly 512 KiB"
}

# Refuse common build-machine path leaks before the binary leaves the lab.
$ExeBytes = [IO.File]::ReadAllBytes((Join-Path $Stage "SyphonFilter2Recompiled.exe"))
$ExeText = [Text.Encoding]::ASCII.GetString($ExeBytes)
$Leaks = @("I:/Projects", "I:\Projects", "Z:/Emulators", "Alexbeav", "generated-disc1") |
    Where-Object { $ExeText.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
if ($Leaks) { throw "Executable contains private build path marker(s): $($Leaks -join ', ')" }

if (Test-Path -LiteralPath $Zip) { Remove-Item -LiteralPath $Zip -Force }
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $Zip -Force
python (Join-Path $Root "tools/public_repo_audit.py") --archive $Zip --sha256
if ($LASTEXITCODE -ne 0) { throw "Release audit failed" }

Write-Host "Executable SHA-256: $ActualHash"
Write-Host "Release ZIP: $Zip"

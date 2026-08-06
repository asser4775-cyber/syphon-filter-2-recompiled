param(
    [Parameter(Mandatory = $true)] [string]$CliDir,
    [Parameter(Mandatory = $true)] [string]$FrameworkRoot,
    [string]$Output = "dist/syphon-filter-2-recompiled-kit-windows-x64.zip"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Cli = Resolve-Path $CliDir
$Framework = Resolve-Path $FrameworkRoot
$OutputPath = Join-Path $Root $Output
$StageRoot = Join-Path $Root "dist\kit-stage"
$Stage = Join-Path $StageRoot "syphon-filter-2-recompiled-kit"

if (Test-Path -LiteralPath $StageRoot) {
    Remove-Item -LiteralPath $StageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force `
    $Stage,(Join-Path $Stage "seeds"), `
    (Join-Path $Stage "psxrecomp-cli\libexec"), `
    (Join-Path $Stage "psxrecomp-cli\share"), `
    (Split-Path $OutputPath) | Out-Null

Copy-Item -LiteralPath (Join-Path $Root "release\README-PLAYER.md") -Destination (Join-Path $Stage "README.md")
Copy-Item -LiteralPath (Join-Path $Root "release\SETUP.ps1") -Destination $Stage
Copy-Item -LiteralPath (Join-Path $Root "release\extract_boot_exe.py") -Destination $Stage
foreach ($Name in @("game.toml", "CMakeLists.txt", "settings.toml", "keybinds.ini")) {
    Copy-Item -LiteralPath (Join-Path $Root $Name) -Destination $Stage
}
Copy-Item -LiteralPath (Join-Path $Root "seeds\functions.txt") -Destination (Join-Path $Stage "seeds")
Copy-Item -LiteralPath (Join-Path $Framework "LICENSE") -Destination (Join-Path $Stage "LICENSE-psxrecomp")
Copy-Item -LiteralPath (Join-Path $Framework "THIRD_PARTY_ATTRIBUTION.md") -Destination $Stage

Copy-Item -LiteralPath (Join-Path $Cli "psxrecomp.exe") -Destination (Join-Path $Stage "psxrecomp-cli")
foreach ($Name in @("psxrecomp-game.exe", "psxrecomp-bios.exe", "psxrecomp-toml.exe")) {
    Copy-Item -LiteralPath (Join-Path $Cli "libexec\$Name") -Destination (Join-Path $Stage "psxrecomp-cli\libexec")
}
Copy-Item -LiteralPath (Join-Path $Cli "share\phase2_ghidra_seeds.json") -Destination (Join-Path $Stage "psxrecomp-cli\share")

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}
Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $OutputPath
python (Join-Path $Root "tools\public_repo_audit.py") --archive $OutputPath --sha256
if ($LASTEXITCODE -ne 0) { throw "owned-input kit audit failed" }
Write-Host "Owned-input kit: $OutputPath"

param(
    [Parameter(Mandatory = $true)]
    [string]$DiscPath,
    [string]$StageDir = "release-stage/syphon-filter-2-recompiled-v0.1.0-alpha-windows-x64",
    [int]$TimeoutSeconds = 15
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Stage = Resolve-Path (Join-Path $Root $StageDir)
$Exe = Join-Path $Stage "SyphonFilter2Recompiled.exe"
if (-not (Test-Path -LiteralPath $DiscPath -PathType Leaf)) {
    throw "Disc image not found: $DiscPath"
}

$Start = [Diagnostics.ProcessStartInfo]::new()
$Start.FileName = $Exe
$Start.WorkingDirectory = $Stage
$Start.UseShellExecute = $false
$Start.CreateNoWindow = $true
$Start.RedirectStandardOutput = $true
$Start.RedirectStandardError = $true
foreach ($Arg in @(
    "--game", "game.toml", "--disc", (Resolve-Path $DiscPath).Path,
    "--memcard-dir", "saves", "--headless"
)) {
    $Start.ArgumentList.Add($Arg)
}

$Process = [Diagnostics.Process]::Start($Start)
$Exited = $Process.WaitForExit($TimeoutSeconds * 1000)
if ($Exited) {
    $Stdout = $Process.StandardOutput.ReadToEnd()
    $Stderr = $Process.StandardError.ReadToEnd()
    throw "Packaged runtime exited early ($($Process.ExitCode)).`n$Stdout`n$Stderr"
}

$Process.Kill()
$Process.WaitForExit()
Write-Host "Package smoke PASS: runtime remained active for $TimeoutSeconds seconds (PID $($Process.Id))"

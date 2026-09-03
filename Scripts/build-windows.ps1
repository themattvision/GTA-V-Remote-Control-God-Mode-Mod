param(
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE "Downloads\GodMode Mod Remote Control Windows")
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$solution = Join-Path $repositoryRoot "Windows\GTA-Remote.Windows.slnx"
$project = Join-Path $repositoryRoot "Windows\GTABridge.Windows\GTABridge.Windows.csproj"
$publishDirectory = Join-Path $OutputDirectory "GodMode Mod Remote Control"
$archive = Join-Path $OutputDirectory "Windows-GodMode-Mod-Remote-Control-v0.3.0.zip"

dotnet test $solution -c Release

if (Test-Path $publishDirectory) {
    Remove-Item $publishDirectory -Recurse -Force
}
New-Item $publishDirectory -ItemType Directory -Force | Out-Null

dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -o $publishDirectory

Copy-Item (Join-Path $repositoryRoot "Windows\README.md") $publishDirectory
if (Test-Path $archive) {
    Remove-Item $archive -Force
}
Compress-Archive -Path (Join-Path $publishDirectory "*") -DestinationPath $archive
Write-Host "Build Windows creato: $archive"

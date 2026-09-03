param(
    [string]$Version = "0.3.0",
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE "Downloads\GodMode Mod Remote Control Windows"),
    [string]$MingwBin = "C:\msys64\mingw64\bin",
    [string]$InnoSetupCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$solution = Join-Path $repositoryRoot "Windows\GTA-Remote.Windows.slnx"
$project = Join-Path $repositoryRoot "Windows\GTABridge.Windows\GTABridge.Windows.csproj"
$modSourceDirectory = Join-Path $repositoryRoot "Mods\GTARemoteBridge"
$installerScript = Join-Path $repositoryRoot "Installer\GodModeModRemoteControl.iss"
$buildDirectory = Join-Path $OutputDirectory "build"
$publishDirectory = Join-Path $buildDirectory "app"
$modBuildDirectory = Join-Path $buildDirectory "mod"
$installerOutputDirectory = Join-Path $OutputDirectory "installer"
$importLibrary = Join-Path $modBuildDirectory "libScriptHookV.a"
$modBinary = Join-Path $modBuildDirectory "GTARemoteBridge.asi"

function Resolve-Tool([string]$Directory, [string[]]$Names) {
    foreach ($name in $Names) {
        $candidate = Join-Path $Directory $name
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    throw "Tool richiesto non trovato in $Directory: $($Names -join ', ')"
}

$dllTool = Resolve-Tool $MingwBin @("x86_64-w64-mingw32-dlltool.exe", "dlltool.exe")
$compiler = Resolve-Tool $MingwBin @("x86_64-w64-mingw32-g++.exe", "g++.exe")
if (-not (Test-Path $InnoSetupCompiler)) {
    throw "Tool richiesto non trovato: $InnoSetupCompiler"
}

dotnet test $solution -c Release

if (Test-Path $buildDirectory) {
    Remove-Item $buildDirectory -Recurse -Force
}
New-Item $publishDirectory -ItemType Directory -Force | Out-Null
New-Item $modBuildDirectory -ItemType Directory -Force | Out-Null
New-Item $installerOutputDirectory -ItemType Directory -Force | Out-Null

dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -o $publishDirectory

Copy-Item (Join-Path $repositoryRoot "Windows\README.md") $publishDirectory

& $dllTool `
    -d (Join-Path $modSourceDirectory "ScriptHookV.def") `
    -l $importLibrary
if ($LASTEXITCODE -ne 0) { throw "Creazione import library ScriptHook V fallita." }

& $compiler `
    -std=c++17 `
    -O2 `
    -shared `
    -static-libgcc `
    -static-libstdc++ `
    -o $modBinary `
    (Join-Path $modSourceDirectory "GTARemoteBridge.cpp") `
    $importLibrary `
    "-Wl,--subsystem,windows" `
    "-Wl,--kill-at"
if ($LASTEXITCODE -ne 0) { throw "Build di GTARemoteBridge.asi fallita." }

& $InnoSetupCompiler `
    "/DAppVersion=$Version" `
    "/DPublishDir=$publishDirectory" `
    "/DModBinary=$modBinary" `
    "/DOutputDir=$installerOutputDirectory" `
    $installerScript
if ($LASTEXITCODE -ne 0) { throw "Build dell'installer Windows fallita." }

$installer = Join-Path $installerOutputDirectory "Windows-GodMode-Mod-Remote-Control-Setup-v$Version.exe"
if (-not (Test-Path $installer)) {
    throw "Installer atteso non trovato: $installer"
}

Write-Host "Installer Windows creato: $installer"

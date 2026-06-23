# Runs Onze on MEmu/LDPlayer-style emulators.
#
# Why this exists: these emulators' package manager installs apps as ARM
# (primaryCpuAbi=armeabi-v7a) even on x86_64 images, and their ARM->x86
# translator cannot load Flutter's native library, crashing on startup with
# "UnsatisfiedLinkError: dlopen failed: ELF program header is invalid".
# Plain `flutter run` reinstalls without an ABI override, so it always breaks.
# This script builds an x86_64-only debug APK, installs it forcing the ABI,
# launches the app and attaches the Flutter tool for hot reload.
param(
    [string]$DeviceId = "127.0.0.1:21503"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

flutter build apk --debug --target-platform android-x64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

adb -s $DeviceId install -r --abi x86_64 build\app\outputs\flutter-apk\app-debug.apk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

adb -s $DeviceId shell am start -n com.example.onze_app/.MainActivity

# Attaches to the running app: hot reload (r), hot restart (R), quit (q).
flutter attach -d $DeviceId

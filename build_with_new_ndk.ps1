Write-Host "Starting APK build with new NDK version 29.0.13113456..."
$env:JAVA_HOME = "C:\Users\rishw\Java\jdk-17.0.12"
Write-Host "Using JAVA_HOME: $env:JAVA_HOME"

$flutterPath = "C:\Users\rishw\dev\flutter\bin\flutter.bat"

Write-Host "Running Flutter clean..."
& $flutterPath clean

Write-Host "Running Flutter pub get..."
& $flutterPath pub get

Write-Host "Building APK with --release flag..."
& $flutterPath build apk --release --verbose

Write-Host "Checking for APK..."
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Write-Host "SUCCESS: APK built successfully at: $apkPath"
} else {
    Write-Host "ERROR: APK not found at expected location: $apkPath"
    
    # Try to find it elsewhere
    Write-Host "Searching for APK files..."
    $apkFiles = Get-ChildItem -Path "build" -Recurse -Filter "*.apk"
    if ($apkFiles.Count -gt 0) {
        Write-Host "Found APK file(s):"
        $apkFiles | ForEach-Object { Write-Host $_.FullName }
    } else {
        Write-Host "No APK files found in the build directory."
    }
}

Write-Host "Build process completed." 
Write-Host "Starting APK build..."
$env:JAVA_HOME = "C:\Users\rishw\Java\jdk-17.0.12"
Write-Host "Using JAVA_HOME: $env:JAVA_HOME"

Write-Host "Running Flutter clean..."
Start-Process -FilePath "C:\Users\rishw\dev\flutter\bin\flutter.bat" -ArgumentList "clean" -NoNewWindow -Wait -RedirectStandardOutput "flutter_clean_out.txt" -RedirectStandardError "flutter_clean_err.txt"
Get-Content "flutter_clean_out.txt", "flutter_clean_err.txt"

Write-Host "Running Flutter pub get..."
Start-Process -FilePath "C:\Users\rishw\dev\flutter\bin\flutter.bat" -ArgumentList "pub", "get" -NoNewWindow -Wait -RedirectStandardOutput "flutter_pub_out.txt" -RedirectStandardError "flutter_pub_err.txt"
Get-Content "flutter_pub_out.txt", "flutter_pub_err.txt"

Write-Host "Building APK with --release flag..."
Start-Process -FilePath "C:\Users\rishw\dev\flutter\bin\flutter.bat" -ArgumentList "build", "apk", "--release", "--verbose" -NoNewWindow -Wait -RedirectStandardOutput "flutter_build_out.txt" -RedirectStandardError "flutter_build_err.txt"
Get-Content "flutter_build_out.txt", "flutter_build_err.txt"

Write-Host "Checking for APK..."
$apkPath = Join-Path (Get-Location).Path "..\build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Write-Host "APK built successfully at: $apkPath"
} else {
    Write-Host "APK not found at expected location: $apkPath"
    
    # Try to find it elsewhere
    Write-Host "Searching for APK files..."
    $apkFiles = Get-ChildItem -Path "..\build" -Recurse -Filter "*.apk"
    if ($apkFiles.Count -gt 0) {
        Write-Host "Found APK file(s):"
        $apkFiles | ForEach-Object { Write-Host $_.FullName }
    } else {
        Write-Host "No APK files found in the build directory."
    }
}

Write-Host "Build process completed." 
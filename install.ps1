# moon-release installer for Windows
# Usage: irm https://raw.githubusercontent.com/dijdzv/moon-release/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$Repo = "dijdzv/moon-release"
$BinaryName = "moon-release.exe"
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { "$env:USERPROFILE\.local\bin" }

function Get-LatestVersion {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
    return $response.tag_name -replace '^v', ''
}

function Install-MoonRelease {
    Write-Host "Installing moon-release..." -ForegroundColor Cyan
    Write-Host ""

    # Check architecture
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($arch -ne "X64") {
        Write-Host "Error: Unsupported architecture: $arch" -ForegroundColor Red
        Write-Host "Supported: x86_64 (X64)" -ForegroundColor Red
        exit 1
    }
    Write-Host "Detected platform: windows-x86_64"

    # Get latest version
    $version = Get-LatestVersion
    if (-not $version) {
        Write-Host "Error: Could not determine latest version" -ForegroundColor Red
        exit 1
    }
    Write-Host "Latest version: v$version"

    # Construct download URL
    $artifactName = "moon-release-windows-x86_64.exe"
    $url = "https://github.com/$Repo/releases/download/v$version/$artifactName"
    Write-Host "Download URL: $url"

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Download binary
    Write-Host ""
    Write-Host "Downloading..."
    $destPath = Join-Path $InstallDir $BinaryName
    try {
        Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing
    } catch {
        Write-Host "Error: Failed to download binary" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Installed to: $destPath" -ForegroundColor Green

    # Check if install dir is in PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$InstallDir*") {
        Write-Host ""
        Write-Host "WARNING: $InstallDir is not in your PATH" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Add it to your PATH by running:" -ForegroundColor Yellow
        Write-Host "  `$env:PATH += `";$InstallDir`"" -ForegroundColor White
        Write-Host ""
        Write-Host "Or permanently add it:" -ForegroundColor Yellow
        Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$InstallDir', 'User')" -ForegroundColor White

        # Offer to add to PATH
        Write-Host ""
        $addToPath = Read-Host "Add to PATH now? (y/N)"
        if ($addToPath -eq 'y' -or $addToPath -eq 'Y') {
            $newPath = $userPath + ";" + $InstallDir
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            $env:PATH = $env:PATH + ";" + $InstallDir
            Write-Host "Added to PATH!" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host "Run 'moon-release --help' to get started."
}

Install-MoonRelease

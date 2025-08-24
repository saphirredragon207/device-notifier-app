@echo off
echo Making shell scripts executable for Windows...

echo Setting permissions for build-all-installers.sh...
git update-index --chmod=+x scripts/build-all-installers.sh

echo Setting permissions for build-docker.sh...
git update-index --chmod=+x scripts/build-docker.sh

echo Setting permissions for build-pkg.sh...
git update-index --chmod=+x installers/macos/build-pkg.sh

echo.
echo Scripts are now marked as executable in Git.
echo If using Git Bash or WSL, the scripts should now be executable.
echo.
echo Note: On Windows, you can also run the Windows-specific scripts:
echo   installers\windows\build-msi.bat
echo   installers\windows\build-msi.ps1
echo.
echo Or use the cross-platform script:
echo   scripts\build-all-installers.sh
echo.
pause

@echo off
echo Updating Flutter dependencies...

rem Get outdated packages
echo Checking for outdated packages...
flutter pub outdated

rem Update to latest compatible versions
echo Updating to latest compatible versions...
flutter pub upgrade

echo Cleaning project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building app...
flutter build apk --debug

echo Done! Check the FIREBASE_FIXES.md file for more information on the changes made.
pause 
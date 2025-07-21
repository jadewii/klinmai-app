#!/bin/bash

echo "Fixing Xcode project references..."

# 1. Kill Xcode if running
echo "Closing Xcode..."
osascript -e 'quit app "Xcode"'
sleep 2

# 2. Clear all Xcode caches
echo "Clearing Xcode caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/ModuleCache/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*

# 3. Remove any workspace data from the project
echo "Cleaning project workspace data..."
cd /Users/jade/Klinmai
rm -rf .build
rm -rf .swiftpm

# 4. Open the new project location
echo "Opening Klinmai project..."
open /Users/jade/Klinmai/Package.swift

echo "Done! Xcode should now open with the correct project location."
echo "If you still see errors, wait for Xcode to fully load and then:"
echo "1. Go to Product → Clean Build Folder (Shift+Cmd+K)"
echo "2. Go to Product → Build (Cmd+B)"
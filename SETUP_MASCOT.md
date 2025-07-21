# 🦕 How to Add Your Pink Dinosaur Mascot

## Quick Setup (Option 1 - Automatic Loading)

1. Save your pink dinosaur image to one of these locations on your Mac:
   - `~/Desktop/klinmai-mascot.png`
   - `~/Downloads/klinmai-mascot.png`
   - `~/Pictures/klinmai-mascot.png`
   - `~/Documents/klinmai-mascot.png`

2. Run the app - it will automatically find and load your mascot!

## Custom Path (Option 2)

1. Open `/Users/jade/Klinmai/Views/MascotImageLoader.swift`
2. Edit the `imagePaths` array and add your specific image path:
   ```swift
   private let imagePaths = [
       "/Users/jade/your-actual-path/pink-dinosaur.png",  // <-- Add your path here
       // ... other paths
   ]
   ```

## Interactive Picker (Option 3)

To use the file picker version:
1. Replace `MascotImageLoader` with `MascotImagePicker` in MascotImage.swift
2. Click on the mascot area to choose your image file
3. The app will remember your choice

## Test Your Mascot

Run this command to check if your image loads:
```bash
# Check if file exists
ls -la ~/Desktop/klinmai-mascot.png

# Or wherever you saved it
ls -la /path/to/your/pink-dinosaur.png
```

## Supported Formats
- PNG (recommended)
- JPEG/JPG
- GIF (static only)

The app will show your cute pink dinosaur everywhere:
- In the glowing "CLEAN MY COMPUTER" button
- In the app header
- Animated during cleaning! 💖
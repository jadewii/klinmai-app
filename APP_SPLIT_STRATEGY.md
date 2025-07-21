# Klinmai / Imagimai App Split Strategy

## Overview

We're splitting Klinmai into two focused apps:
- **Klinmai**: File-first productivity cleaner (utility-focused)
- **Imagimai**: Offline-first image curation and gallery builder (creative-focused)

## Implementation Status

### ✅ Completed for Klinmai
1. Removed all media preview components (thumbnails, video playback)
2. Created SimplifiedArchiveRow and SimplifiedArchiveGridItem
3. Added upgrade prompts for media files → Imagimai/Audiomai
4. Removed AVKit and QuickLookThumbnailing dependencies
5. Kept all file management functionality intact

### 🚀 Performance Benefits
- No more thumbnail generation overhead
- No AVPlayer instances to manage
- Significantly reduced memory usage
- Instant file list loading
- No beach ball spinners from video previews

### 📱 User Experience Changes
- Files display with type icon, name, size, and date only
- Media files show "View in Imagimai/Audiomai" buttons
- Clean, text-based interface focused on file management
- Faster, more responsive UI

## Next Steps

### For Klinmai
1. [ ] Remove remaining preview-related code
2. [ ] Update app description to emphasize utility focus
3. [ ] Create GitHub repository: `klinmai-app`
4. [ ] Polish upgrade prompts with App Store links

### For Imagimai (New App)
1. [ ] Fork current Klinmai codebase
2. [ ] Change color theme to baby blue (#3d7dad)
3. [ ] Filter to only scan image/GIF files
4. [ ] Re-enable and enhance preview features
5. [ ] Add Gallery, Collections, Moodboard tabs
6. [ ] Implement AI-powered image organization
7. [ ] Create GitHub repository: `imagimai-app`

## Repository Setup

### Klinmai Repository
```bash
git init
git remote add origin https://github.com/jadewii/klinmai-app.git
git add .
git commit -m "Initial commit: Klinmai utility-focused file cleaner"
git push -u origin main
```

### Imagimai Repository (after forking)
```bash
git clone https://github.com/jadewii/klinmai-app.git imagimai-app
cd imagimai-app
git remote set-url origin https://github.com/jadewii/imagimai-app.git
# Make Imagimai-specific changes
git commit -m "Fork Klinmai to create Imagimai image gallery app"
git push -u origin main
```

## Branding Guidelines

### Klinmai
- **Focus**: Files, Utility, Cleanup
- **Color**: Pink (existing)
- **Mascot**: Klinmai the Cleanup Dino
- **Tagline**: "Your offline AI cleaning companion"

### Imagimai
- **Focus**: Images, Gallery, Creativity
- **Color**: Baby Blue (#3d7dad)
- **Mascot**: Imagimai the Art Curator Dino
- **Tagline**: "Your offline image gallery curator"

## Benefits of Split

1. **Performance**: Each app optimized for its specific use case
2. **User Experience**: Clear purpose for each app
3. **Development**: Easier to maintain and add features
4. **Marketing**: Target different user needs
5. **Monetization**: Different pricing strategies possible
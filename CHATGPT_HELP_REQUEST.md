# Klinmai - macOS File Cleaning App Performance Optimization Help

## App Overview

Klinmai is a native macOS desktop app built with SwiftUI that helps users clean and organize their files. It's part of the Dinomai suite of apps and features a playful pink aesthetic with a dinosaur mascot.

### Key Features:
1. **Smart Archive System** - Scans for old/large files across Desktop, Downloads, Documents, Pictures, Movies, and iCloud Drive
2. **File Preview** - Grid/list views with inline thumbnails and video previews
3. **Smart Suggestions** - AI-like local analysis that suggests file groupings, duplicates, and cleanup actions
4. **iCloud Integration** - Shows iCloud sync status (☁️, ⬇️, ✅) and handles cloud files
5. **Action Bar** - Bottom toolbar with Move, Rename, Share, Favorite, Collab, and Archive buttons
6. **Real-time Filtering** - Filter by file type (Videos, Audio, Images, GIFs, Documents) and iCloud status

## Current Performance Issues

### 🚨 CRITICAL ISSUE: Everything is extremely slow, making the app unusable

1. **File Scanning Takes Forever**
   - Scanning directories with many files (1000+) is very slow
   - Even with progressive loading, initial results take too long to appear
   - Users see empty screen for 10-30 seconds before any files show

2. **Video Preview Performance**
   - Video hover preview causes spinning beach ball
   - Creating AVPlayer instances for each video is expensive
   - No caching of video thumbnails or players

3. **Thumbnail Generation**
   - QLThumbnailGenerator is called for every file on every view
   - No persistent cache for generated thumbnails
   - Grid view with 100+ files becomes laggy

4. **UI Responsiveness**
   - Scrolling through file lists stutters
   - Switching between grid/list view freezes UI
   - Filter changes cause full re-render

## Technical Stack

- **Language**: Swift 5.9
- **Framework**: SwiftUI
- **Platform**: macOS 13+
- **Key Libraries**: 
  - AVKit for video playback
  - QuickLookThumbnailing for previews
  - FileManager for file operations

## Current Implementation Issues

### File Scanning (SmartArchiveManager.swift)
```swift
private func scanDirectory(_ directory: URL, cutoffDate: Date, sizeThreshold: Int64) async -> [ArchiveCandidate] {
    // Currently enumerates ALL files, even if they don't meet criteria
    // No batching or pagination
    // Blocks on iCloud status checks
}
```

### Video Preview (CompactArchiveView.swift)
```swift
// Creates new AVPlayer for every hover event
private func playVideo() {
    if videoPlayer == nil {
        videoPlayer = AVPlayer(url: candidate.url)
        videoPlayer?.isMuted = true
    }
    videoPlayer?.seek(to: CMTime.zero)
    videoPlayer?.play()
    isPlaying = true
}
```

### Thumbnail Loading
```swift
// No caching, generates fresh thumbnail every time
private func generateThumbnail() async {
    let size = CGSize(width: 240, height: 240)
    let request = QLThumbnailGenerator.Request(
        fileAt: candidate.url,
        size: size,
        scale: 2.0,
        representationTypes: .thumbnail
    )
    // This is called for EVERY file in view
}
```

## What We Need Help With

1. **Instant File Loading**
   - How can we make files appear instantly when opening the app?
   - Should we implement a SQLite cache of file metadata?
   - How to efficiently scan 10,000+ files without blocking UI?

2. **Smooth Video Previews**
   - Best practice for hover video previews in SwiftUI?
   - Should we pre-generate video thumbnails?
   - How to reuse AVPlayer instances efficiently?

3. **Performance Architecture**
   - Should we move to Combine/async streams for file enumeration?
   - How to implement proper thumbnail caching (memory + disk)?
   - Best practices for virtualized scrolling in SwiftUI?

4. **Memory Management**
   - Currently no cleanup of video players or thumbnails
   - How to implement proper resource pooling?
   - When to release cached data?

## Constraints

- Must remain 100% offline (no cloud services)
- Need to support iCloud Drive files
- Must work with files ranging from KB to GB
- Target: Show first results in <1 second, full scan <5 seconds

## Example User Flow That's Too Slow

1. User opens app → Empty screen for 5-10 seconds
2. Files start appearing → Each thumbnail takes 1-2 seconds to load
3. User hovers over video → Beach ball spinner for 2-3 seconds
4. User scrolls → Janky, stuttering scroll
5. User clicks grid view → UI freezes for 3-5 seconds

## Question for ChatGPT

Given our SwiftUI macOS app architecture and the performance issues described above, what are the best practices and architectural changes we should implement to achieve:

1. Instant file listing (< 1 second to first result)
2. Smooth 60fps scrolling with hundreds of files
3. Instant video hover previews without beach balls
4. Efficient memory usage that scales to 10,000+ files

Please provide specific Swift/SwiftUI code examples and architectural recommendations. We're open to major refactoring if needed to achieve native-app-level performance.
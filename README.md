# Overview: Window Previews on macOS

Create live window previews for any application, and activate them efficiently with built-in task-switching

![Example Screenshot](https://downloads.williampierce.io/Banner.jpg)

Perfect for multi boxing in EVE Online on macOS!! 

## Forked

(Forked from https://github.com/williamcpierce/Overview)

I forked this repository because the developer has gone radio silent. There was a critical that I used AI to fix:

> A system interruption could stop a live window preview without capture resuming
> automatically. The coordinator treated ScreenCaptureKit's `systemStoppedStream`
> error as fatal, stopping capture and clearing the preview. Other recoverable errors
> attempted to restart through `startCapture()`, but its `isCapturing` guard could
> return immediately while the old capture state was still active. A stream ending
> without an error also stopped capture without attempting recovery.

Hence the need to fork and rebuild a new DMG for macOS. 

## Beta Release

**Note: Overview is beta software. It may contain bugs or unexpected behavior. Use at your own risk.**

## Features

- **Live Window Previews:** Real-time window previews with configurable frame rates and automatic hiding
- **Quick Application Switching:** Switch applications through preview clicks or keyboard shortcuts
- **Preview Customization:** Customize preview window appearance, visibility, and saving/restoration options
- **Glanceable Info Overlays:** Display source app names, window titles, and focus status at a glance
- **Saved Preview Layouts:** Save and restore collections of preconfigured preview windows

## System Requirements

-   macOS Ventura (13.0) or later
-   Screen Recording permission (required for window capture)

## Installation

1. Download the latest version from the Releases panel here on GitHub.
2. Mount the disk image and drag Overview into your Applications folder.
3. Run the application.

## Updates and Help

Use **Help → View Releases** to download updates from [GitHub Releases](https://github.com/mrcrilly/Overview/releases). Updates are installed manually; the app does not check for or download updates in the background.

For help, bug reports, and feature requests, use [this repository’s issues](https://github.com/mrcrilly/Overview/issues).

## Usage

### Quick Start

1. Launch Overview and grant screen recording permission when prompted
2. Create a new preview window from the menu bar icon (⌘N)
3. Select a window to capture from the source windows list
4. Enable edit mode to move/resize preview windows
5. Customize behavior through the settings panel (⌘,)

### Controls

-   Left-click preview: Switch to source application
-   Right-click preview: Access context menu
    -   Toggle Edit Mode for repositioning/resizing
    -   Stop capture
    -   Close preview window
-   `⌘N` Create new preview window
-   `⌘E` Toggle edit mode
-   `⌘,` Open settings

### Settings

See setting menu info panels for full details

-   Previews
    -   Frame Rate
    -   Preview Hiding
        -   Hide previews for inactive source applications
        -   Hide preview for focused source window
        -   Toggle hiding all previews
-   Windows
    -   Appearance
        -   Opacity
        -   Default dimensions
        -   Shadows
        -   Synchronize aspect ratio
    -   System Visibility
        -   Show windows in Mission Control
        -   Show windows on all desktops (including fullscreen)
    -   Management
        -   Always create window on launch
        -   Close window with preview source
        -   Save window positions on quit
        -   Restore window positions on launch
- Overlays
    -   Source Focus
        -   Border width
        -   Border color
    -   Source Title
        -   Font size
        -   Background opacity
        -   Location
        -   Type (window, application, or both)
-   Layouts
    -   Window Layouts
        - Create layouts to save window arrangements
        - Apply layouts to restore window configurations
        - Update existing layouts
    - Apply layout on launch
    - Close all windows when applying layouts
-   Shortcuts
    -   Source Activation
        -   Keyboard shortcuts for focusing source windows
        -   Multiple source window titles per shortcut for cycling
        -   Enable or disable individual shortcuts
-   Sources
    -   Source Application Filter
        -   Source list filtering
    -   Filter mode (blocklist/allowlist)

## Privacy & Security

Overview requires Screen Recording permission to function, but:

-   Only captures window content for preview purposes
-   Does not store or transmit window content
-   All operations remain local to the device

## Development

### Technical Requirements

-   Xcode 15.0
-   Swift 5.0
-   macOS 13.0+ deployment target

### Frameworks and Libraries

-   SwiftUI for user interface
-   ScreenCaptureKit for window capture
-   KeyboardShortcuts for shortcut handling

### Coding Standards

The project adheres to a style guide (see [STYLE.md](https://github.com/williamcpierce/Overview/blob/main/STYLE.md)) that emphasizes:

-   Self-documenting code with clear naming
-   Consistent file organization and documentation
-   Structured logging with appropriate levels
-   Clear separation of concerns and modularity

## License

This project is MIT licensed (see [LICENSE.md](https://github.com/mrcrilly/Overview/blob/main/LICENSE.md))

## Acknowledgments

The design, features, and general purpose of Overview are heavily inspired by [Eve-O Preview](https://github.com/Proopai/eve-o-preview).

Eve-O Preview was originally developed by StinkRay, and is currently maintained by Dal Shooth and Devilen.

Parts of this application include code derived from Apple Inc.'s ScreenRecorder sample code, used under the MIT License.

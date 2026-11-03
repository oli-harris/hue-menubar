<p align="center">
  <img src="huemenubar/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" alt="Hue Menubar icon" width="128">
</p>

<h1 align="center">Hue Menubar</h1>

<p align="center">
  A simple, elegant macOS menubar app for setting Philips Hue scenes.
</p>

## Features

- Activate any Hue scene from the menubar, grouped by room
- Keyboard shortcuts: <kbd>⌘1</kbd>–<kbd>⌘9</kbd> for scenes, <kbd>⌘0</kbd> for all lights off
- Scenes editor to order and select which scenes appear in the menu
- Guided bridge setup with automatic discovery and pairing
- Launch at login
- Talks to the bridge directly over the local network, with no cloud account needed

## Requirements

- macOS 14 or later
- A Philips Hue Bridge on the same network

## Install

1. Download `HueMenubar.zip` from the [latest release](https://github.com/oli-harris/hue-menubar/releases/latest) and unzip it.
2. Move `huemenubar.app` to `/Applications`.
3. Right-click the app and choose **Open**.

> [!NOTE]
> Release builds are unsigned, so macOS may block opening.

## Setup

On first launch, settings open on the **Bridge** tab. Follow the guided flow: the app finds your bridge, then asks you to press the button on top of it to pair. Once paired, your rooms and scenes appear in the menubar menu.

## Build from source

Requires Xcode with the macOS 14 SDK.

```bash
git clone https://github.com/oli-harris/hue-menubar.git
cd hue-menubar
xcodebuild -project huemenubar.xcodeproj -scheme huemenubar -configuration Release build
```

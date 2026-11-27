<p align="center">
  <img src="huemenubar/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" alt="Hue for macOS icon" width="128">
</p>

<h1 align="center">Hue for macOS</h1>

<p align="center">
  A native macOS: menu bar app, CLI tool and Raycast extension. Built for Philips Hue™.
</p>

## What's included

- **Menubar app:** activate any scene from the menu, grouped by room
- **CLI:** a `hue` command to control lights, rooms, colours and scenes from the terminal
- **Raycast extension:** control lights, rooms, colours, brightness and scenes from Raycast

## Features

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

To use the `hue` command or the Raycast extension, see [Command line](#command-line) and [Raycast](#raycast) below.

## Setup

On first launch, settings open on the **Bridge** tab. Follow the guided flow: the app finds your bridge, then asks you to press the button on top of it to pair. Once paired, your rooms and scenes appear in the menubar menu.

## Command line

The app includes a `hue` command. Add the app's Resources folder to your `PATH`, then open a new Terminal window:

```bash
echo 'export PATH="/Applications/huemenubar.app/Contents/Resources:$PATH"' >> ~/.zshrc
```

Settings > General has a button that copies this command with the app's real location. If you built from source, use the path to your built `huemenubar.app` instead. The app must be paired first.

Run `hue help` for every command. A few examples:

```bash
hue rooms
hue on "Living Room" 60
hue colour desk "#ff8800"
hue scene "Living Room" Relax
```

## Raycast

A [Raycast](https://raycast.com) extension in `raycast/` wraps the command line tool with commands for Control Lights, Set Scene, Set Colour, Set Brightness and Turn on Room / Turn off Room. It needs [Node](https://nodejs.org) and the Hue for macOS app, which it finds at `/Applications/huemenubar.app` (change it in the extension's preferences).

### Install the extension

```bash
cd raycast
npm install
npm run build
```

Then run **Import Extension** in Raycast and choose the `raycast` folder. The extension stays installed after the build. Use `npm run dev` instead while developing.

### Patch Raycast (optional glow)

The scene, brightness and colour grids can glow in the colour of what they show. Raycast has no API for this, so `raycast/glow-patch/patch.sh` injects a stylesheet and script into Raycast's launcher page and restarts Raycast:

```bash
raycast/glow-patch/patch.sh            # apply
raycast/glow-patch/patch.sh restore    # undo
```

Your terminal app needs access in System Settings > Privacy & Security > App Management first. This is an unsupported hack: Raycast updates replace the page, so rerun the patch after updating Raycast.

Light and room icons are from [hass-hue-icons](https://github.com/arallsopp/hass-hue-icons) by arallsopp, licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Changes: extracted individual icons, recoloured at runtime.

## Build from source

Requires Xcode with the macOS 14 SDK.

```bash
git clone https://github.com/oli-harris/hue-menubar.git
cd hue-menubar
./build.sh
```

This makes an ad-hoc signed build at `build/Build/Products/Release/huemenubar.app`. Copy it to `/Applications` to install:

```bash
cp -R build/Build/Products/Release/huemenubar.app /Applications/
```

Then add it to your `PATH` as described under [Command line](#command-line).

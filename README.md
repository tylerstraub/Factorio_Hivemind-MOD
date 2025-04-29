# Hivemind

A Factorio mod that exports game state information as JSON for consumption by a NodeJS companion service that provides AI agent functionality to the alien faction.

## Overview

Hivemind monitors game events, collects statistics about both player and enemy forces, and exports this data to a JSON file that can be consumed by an external service. This enables AI-driven behavior for the enemy faction in Factorio.

## Features

- **Real-time data export**: Exports game state to JSON file at configurable intervals
- **Event tracking**: Records and summarizes important events such as:
  - Enemy attacks on player bases
  - Player building destruction
  - Unit deaths (both player and enemy)
  - Player deaths
- **Chat monitoring**: Captures in-game chat messages for AI reaction
- **Comprehensive game state**: Tracks:
  - Enemy evolution factor
  - Pollution levels
  - Unit counts for both forces
  - Player research progress
  - Map tags/locations

## Configuration Settings

The mod provides several settings to control its behavior:

**All settings are runtime-global. Admins can change these at runtime from the server/mod settings menu, and changes take effect immediately without a restart.**

| Setting              | Description                                | Default | Range  |
| -------------------- | ------------------------------------------ | ------- | ------ |
| Export Interval      | How often to export JSON data (seconds)    | 1       | 1-3600 |
| Chat Retention Time  | How long to retain chat messages (seconds) | 60      | 1-3600 |
| Max Chat Messages    | Maximum number of chat messages to store   | 5       | 1-100  |
| Event Retention Time | How long to keep event history (seconds)   | 60      | 1-3600 |
| Max Event Groups     | Maximum number of event groups to store    | 5       | 1-100  |

## Installation

1. Download the latest release
2. Place the mod folder in your Factorio mods directory:
   - Windows: `%APPDATA%\Factorio\mods`
   - Linux: `~/.factorio/mods`
   - macOS: `~/Library/Application Support/factorio/mods`
3. Enable the mod in the Factorio Mods menu

## Integration

The mod creates a file named `hivemind.json` in your Factorio scenario directory, which is updated at the configured interval. The external NodeJS service (to be announced) will read this file to provide AI agent functionality.

## JSON Data Format

The exported JSON contains:

- **Game state**: Tick count, game time, evolution factor, pollution level
- **Player data**: Turret counts, research progress, connected players, map tags
- **Enemy data**: Counts of spawners, worms, biters and spitters by type
- **Event summary**: Recent attacks, losses on both sides
- **Chat**: Recent chat messages

## Requirements

- Factorio 2.0 or higher

## Author

Tyler Straub

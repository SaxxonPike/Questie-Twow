# Questie-Twow

Questie 3.7.1 modified to work with Turtle WoW (and probably other clients, who knows.)

This is a work in progress.

### Modifications

- Astrolabe has been updated with new map geometry from the WorldMapArea WDBC file inside the
  game client MPQ. Because Turle WoW introduced new zones and modified existing ones (for example,
  Stormwind has the port now) you really have to re-export and re-convert them. I wrote a tool to
  convert the values, but it's a very manual process.
- Astrolabe will more gracefully handle zones it does not have in its internal geometry database.
  New zones won't matter for Questie since it is not going to have the new Turtle WoW quests in the
  database anyway.

## Installation

Unzip contents to a folder called `!Questie` in your `Interface\AddOns` folder within your
WoW (Vanilla) installation.
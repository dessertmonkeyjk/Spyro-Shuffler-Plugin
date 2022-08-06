# Changelog
## Alpha v1.0

Initial alpha release (very buggy and not feature complete), supports only four games, trackes gem and main collectibles, syncs totals to the hud, triggers based on either per swap or per frame.

Currently, hard-coded to trigger when a main collectible is gotten by the player.

## Alpha v1.0.1

-Fixed bad gamehash for Spyro 1 NTSC (somehow wound up with a "bad" dump that still played fine?)
-Added ability to get levelid for Spyro 1-3 and Spyro 1 Japan
-Updated cold start detection to check level id to see if player is in-game
-Added ability to get life count (HUD, Global) for Spyro 1-3 (not yet implemented)
-Added ability to get health points for Spyro 1-3, excluding Sparks levels (not yet implemented)
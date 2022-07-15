# Spyro Shuffler
This is a plugin for Bizhawk Shuffler v2 for use with games featuring Spyro the Dragon.
The plugin is designed mainly to swap games whenever a collectable is obtain by the player (gems, dragons, orbs, eggs, etc) but can also sync collectables between games.

I mainly gave it a shot one day after somebody made a joke of doing it for a race and I thought "Why not?"

# Current state of the plugin

The plugin is currently in Alpha and is not yet feature complete.

The plugin is functional but currently supports only specific games and version and has little user customization. It's been released as-is and may be very buggy in its current state. If you discover any bugs, add it as an issue to this github repo.

# Supported games
The following games are supported by the plug-in:

* Spyro the Dragon (NTSC)
* Spyro the Dragon (NTSC - Japan)
* Spyro 2: Ripto's Rage (NTSC)
* Spyro: Year of the Dragon (NTSC - Greatest Hits)

Additional game versions are planned to be added in the future.

Demo and early prototypes are currently NOT planned to be added... for now.

# Features

The plug-in does the following:

* Syncs gems across games
* Updates the HUD to show global collectable totals
* Triggers a game swap when a threshold is reached (Ex. gem collected is 5 or higher)

Additional collectables for both syncing and swapping are planned.

# Setup & How to use

You'll need to setup both Bizhawk 2.6.2 and Bizhawk Shuffler v2 before using this plugin. Bizhawk 2.6.2 is the bare minimum that Bizhawk Shuffler v2 supports but newer versions of the script support later versions of the emulator.

Download Bizhawk: https://tasvideos.org/Bizhawk

Download Bizhawk Shuffler v2 (for Bizhawk 2.6.2 only): https://github.com/authorblues/bizhawk-shuffler-2

OR

Download kalumag's 2.6.3-compat branch of Bizhawk Shuffler v2 (for Bizhawk 2.6.3 or above): https://github.com/authorblues/bizhawk-shuffler-2/tree/2.6.3-compat

1. Make sure you have both Bizhawk 2.6.2 configured (bios, controls, etc) and the Bizhawk Shuffler v2 lua script up and running.

2. Place both the spyro-shuffler.lua and spyro-game-hashes.dat in Bizhawk Shuffler's plugins directory.

3. In Bizhawk, go to Tools > Lua Console. In the Lua Console, go to Script > Open Script... and run the shuffler.lua script in the Bizhawk Shuffler folder.

4. In the Bizhawk Shuffler v2 Setup dialog, click Setup Plugins and then activate the Spyro Shuffler plugin.

5. Make sure you've added the needed files to the games folder for Bizhawk Shuffler. Finally click on Start New Session.
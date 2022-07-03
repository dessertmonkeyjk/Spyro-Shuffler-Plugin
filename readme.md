# Spyro Shuffler
This is a plugin for Bizhawk Shuffler v2 for use with games featuring Spyro the Dragon.
Download Bizhawk Shuffler v2 here: https://github.com/authorblues/bizhawk-shuffler-2
The plugin is designed mainly to swap games whenever a collectable is obtain by the player (gems, dragons, orbs, eggs, etc) but can also sync collectables between games.

I mainly gave it a shot one day after somebody made a joke of doing it for a race and I thought "Why not?"

# Supported games
The following games are supported by the plug-in:

* Spyro the Dragon (NTSC)
* Spyro the Dragon (NTSC - Japan)
* Spyro 2: Ripto's Rage (NTSC)
* Spyro: Year of the Dragon (NTSC - Greatest Hits)

Additional games may be added in the future.

# Features

The plug-in does the following:

* Syncs gems across games
* Updates the HUD to show global gem total
* Triggers a game swap when a threshold is reached (Ex. gem collected is 5 or higher)

Additional collectables for both syncing and swapping are planned.

# How to use

1. Make sure you have both Bizhawk 2.6.2 configured and the Bizhawk Shuffler v2 lua script up and running.

2. Place both the spyro-shuffler.lua and spyro-game-hashes.dat in Bizhawk Shuffler's plugins directory.

3. In Bizhawk, go to Tools > Lua Console. In the Lua Console, go to Script > Open Script... and run the shuffler.lua script in the Bizhawk Shuffler folder.

4. In the Bizhawk Shuffler v2 Setup dialouge, click Setup Plugins and then activate the Spyro Shuffler plugin.

5. Make sure you've added the needed files to the games folder for Bizhawk Shuffler. Finally click on Start New Session.
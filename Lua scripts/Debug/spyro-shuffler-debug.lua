local plugin = {}

plugin.name = "Spyro Shuffler (Debug)"
plugin.author = "dessertmonkeyjk"
plugin.minversion = "2.6.2"

plugin.description =
[[
	**DEBUG VERSION! MAY BE UNSTABLE!**
	*Alpha v1.0.3, last updated 09-02-2023*

	Swaps games whenever something is collected in-game, as well as syncs collectables across games.
	Gem and dragon/orb/egg total + hud are synced. Health & Lives also sync.
	
	Currently supported

	Spyro 1 NTSC
	Spyro 1 NTSC (Japan)*
	Spryo 2 NTSC
	Spryo 2 NTSC (Japan)
	Spyro 3 NTSC Greatest Hits

	* Lives/health may not sync, needs testing

	Code Ref
	-gameinfo.getromname returns rom name
	-frames_since_restart returns frames since last swap (shuffler script function)
	-get_tag_from_hash_db returns tag, uses dat file to match key (hash), returns tag (value), dat file contains comments (shuffler script function)

	To-do
	-Rework code so swap trigger & swap total can be set by user (gems, dragon/orb/egg)
	-Add delay on player hit
	!! Bug caused when player is healed while dying, causing a softlock until the music ends!!
		-Put code for triggering based on collectable into function(s)
		-Put code for tracking collectables into function(s) 
			4. (on update) Check for PER FRAME swap threshold (maybe x collected for swap as well but moneybags...)
			5. (pre swap) Add new x collectable gotten to current game in game table
	-Option to have trigger be x collected for current swap, prevent decrease of value by moneybags for trigger purposes
	-Option to switch between x collected PER FRAME or for current swap
]]


plugin.settings = {
	{ name='mainthreshold', type='number', label='Main Swap Threshold (dragon/orbs/eggs)', default=1 },
	{ name='swapwhendamaged', type='boolean', label='Swap when player is damaged', default=1 }
}

-- called once at the start
function plugin.on_setup(data, settings)
	g_debugconsole = true
	g_debugtext = true

	us_swapondamage = settings.swapwhendamaged

	gui.use_surface('client')

	data.tags = data.tags or {}
	data.gemscollected = data.gemscollected or {}
	data.maincollected = data.maincollected or {}
	data.playerhealth = data.playerhealth or {}
	data.playerlives = data.playerlives or {}
	data.coldstart = data.coldstart or {}
end

-- Get game tag 
function get_gametag ()
	local tag = get_tag_from_hash_db(gameinfo.getromhash(), 'plugins/spyro-games-hashes.dat')
	if tag == nil then tag = 'none' end
	return tag
end


-- Solve for x collectable PER FRAME and for current swap, output multiple
function update_collectable_frame (i_coldframe,i_totalcolvar,i_curcolthisframe,i_curcollastframe)
	-- i_coldframe - Frames since cold start
	-- i_curcolthisframe - Collectable value in game this frame
	-- i_curcollastframe - Updated if swap trigger (o_collastframedelta) fails with i_curcolthisframe
	-- i_totalcolvar - Static total collectable from game table
	-- o_collastframedelta - Collectable value collected in game last frame
	-- o_colthisswap - Collectable value in game this swap

	o_collastframedelta = 0
	o_colthisswap = 0

	if i_coldframe >= 2 then 
		o_collastframedelta = i_curcolthisframe - i_curcollastframe
		o_colthisswap = i_curcolthisframe - i_totalcolvar
	end

	return o_colthisswap,o_collastframedelta
end

function get_collectable_ingametable (i_gametable,i_gameinstance)

	-- 1 Get current game col count from game table [gt_realcollectvar] (on swap)
	if i_gametable[i_gameinstance] ~= nil then
		o_gtcollectvar = i_gametable[i_gameinstance]
	else
		o_gtcollectvar = 0
	end

	-- 2 Add up current col total from game table for game instance [g_totalcolvar] (on swap)
	-- Add up total collect var so far for ALL GAMES

	o_gttotalcollectvar = 0

	for key, value in pairs(i_gametable) do 
		o_gttotalcollectvar = o_gttotalcollectvar + value
		-- local gametag = data.tags[key]
		-- console.log(gametag, value)
	end

	return o_gtcollectvar, o_gttotalcollectvar
end

function get_delay_frame (i_currentframe, i_offset)
	o_delayframe = i_currentframe + i_offset

	return o_delayframe
end
-- Specific functions based on game tag, how to get/set values per game
-- Get Global value, Trigger swap on HUD update
-- Spyro 1 HUD defaults to level gems, can be set to total gems on HUD
-- Need to test
	-- Add health/lives for Spyro 1 Japan
-- * = not tested/supported yet
local gamedata = {
	['spyro1ntsc']={ 
		-- Spyro the Dragon NTSC [total gems, gem hud, dragon pre/post collect, levelid, lives, health*]
		-- HUD (0x077FCC) updates based on global value (0x075750), get HUD var for trigger, set both
		-- Lives HUD (0x077FD0) updates based on global value (0x07582C)
		-- Health points (0x078BBC) range from 0-3 
		-- Level ID current (0x0758B4) range from 10 to 64 (first is hub, second is level)
		getgemvar=function() return mainmemory.read_u16_le(0x075860) end,
		getmainvar=function() return mainmemory.read_u16_le(0x077FCC) end,
		getlevelidvar=function() return mainmemory.read_u16_le(0x0758B4) end,
		getlivesvar=function() return mainmemory.read_u16_le(0x07582C) end,
		gethealthvar=function() return mainmemory.read_u16_le(0x078BBC) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x075860, value) end,
		setgemhuds1var=function(value) return mainmemory.write_u16_le(0x077FC8, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x077FCC,value), mainmemory.write_u16_le(0x075750,value) end,
		sethealthvar=function(value) return mainmemory.write_u16_le(0x078BBC, value) end,
		setlivesvar=function(value) return mainmemory.write_u16_le(0x07582C, value) end
	},
	['spyro1ntsc-j']={ 
		-- Spyro the Dragon Japan [total gems, gem hud, dragon pre/post collect, levelid*, lives*, health*]
		-- Dragon HUD (0x081DCC) updates based on global value (0x07F2C0), get HUD var for trigger, set both
		getgemvar=function() return mainmemory.read_u16_le(0x07F3F0) end,
		getmainvar=function() return mainmemory.read_u16_le(0x081DCC) end,
		getlevelidvar=function() return mainmemory.read_u16_le(0x07F448) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x07F3F0, value) end,
		setgemhuds1var=function(value) return mainmemory.write_u16_le(0x081DC8, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x081DCC,value), mainmemory.write_u16_le(0x07F2C0,value) end
	},
	['spyro2ntsc-j']={ 
		-- Spyro 2 NTSC Japan [total gems, gem hud, orb post collect, levelid, lives, health]
		-- Orb global (0x06974C) is updated right before Orb is given, No idea where the HUD value is stored
		-- Lives HUD (0x069DA0) updates based on global value (0x069850)
		-- Health points (0x06CE04) range from 0-3, set to high number on death
		-- Level ID current (0x0696AC) range from 10 to 100+ (first is hub, second is level)
			-- (Unlike Spyro 1, hubs use up to 20 numbers, summer is 10-26, autumn is 30-46, etc), cutscenes start at id 70)
		getgemvar=function() return mainmemory.read_u16_le(0x0697F0) end,
		getmainvar=function() return mainmemory.read_u16_le(0x06974C) end,
		getlevelidvar=function() return mainmemory.read_u16_le(0x0696AC) end,
		getlivesvar=function() return mainmemory.read_u16_le(0x069850) end,
		gethealthvar=function() return mainmemory.read_u16_le(0x06CE04) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x0697F0, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x069D90, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x06974C, value) end,
		sethealthvar=function(value) return mainmemory.write_u16_le(0x06CE04, value) end,
		setlivesvar=function(value) return mainmemory.write_u16_le(0x069850, value) end
	},
	['spyro2ntsc']={ 
		-- Spyro 2 NTSC [total gems, gem hud, orb post collect, talismans, levelid, lives, health]
		-- Orb global (0x06702C) is updated right before Orb is given, No idea where the HUD value is stored
		-- Lives HUD (0x067670) updates based on global value (0x06712C)
		-- Health points (0x06A248) range from 0-3, set to high number on death
		-- Spyro 2 Talismans count (0x067108) updates when one is collected, specific to this game 
		-- Level ID current (0x066F90) range from 10 to 100+ (first is hub, second is level)
			-- (Unlike Spyro 1, hubs use up to 20 numbers, summer is 10-26, autumn is 30-46, etc), cutscenes start at id 70)
		getgemvar=function() return mainmemory.read_u16_le(0x0670CC) end,
		getmainvar=function() return mainmemory.read_u16_le(0x06702C) end,
		getlevelidvar=function() return mainmemory.read_u16_le(0x066F90) end,
		getlivesvar=function() return mainmemory.read_u16_le(0x06712C) end,
		gethealthvar=function() return mainmemory.read_u16_le(0x06A248) end,
		gettalismanvar=function() return mainmemory.read_u16_le(0x067108) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x0670CC, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x067660, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x06702C, value) end,
		sethealthvar=function(value) return mainmemory.write_u16_le(0x06A248, value) end,
		setlivesvar=function(value) return mainmemory.write_u16_le(0x06712C, value) end
	},
	['spyro3ntsc1-1']={ 
		-- Spyro: Year of the Dragon NTSC [total gems, gem hud, egg post collect, talismans*, levelid, lives, health]
		-- Egg global updates the HUD, safe to set Global (0x06C740) and trigger with HUD (0x067410)
		-- Lives HUD (0x0673BC) updates based on global value (0x0673BE)
		-- Health points (0x070688) range  from 0-4 , set to high number on death
		-- *Spyro 2 Talismans count (0x067108) updates when one is collected, specific to this game 
		-- Level ID current (0x06C69C) range from 10 to 80+
			-- (I assume it's similar to Spyro 1 but haven't tested fully, first level is hub, second is level, cutscenes start at id 61)
		getgemvar=function() return mainmemory.read_u16_le(0x06C7FC) end,
		getmainvar=function() return mainmemory.read_u16_le(0x067410) end,
		getlevelidvar=function() return mainmemory.read_u16_le(0x06C69C) end,
		getlivesvar=function() return mainmemory.read_u16_le(0x0673BE) end,
		gethealthvar=function() return mainmemory.read_u16_le(0x070688) end,
		gettalismanvar=function() return mainmemory.read_u16_le(0x067108) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x06C7FC, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x067368, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x06C740,value) end,
		sethealthvar=function(value) return mainmemory.write_u16_le(0x070688, value) end,
		setlivesvar=function(value) return mainmemory.write_u16_le(0x0673BE, value) end
	}
}

-- called each time a game/state loads
function plugin.on_game_load(data, settings)
	
	--Get global data
	plugversion='09-02-2023'
	g_gameinstance = config.current_game
	gt_coldstart = data.coldstart[g_gameinstance]
	us_mainthreshold = settings.mainthreshold

	-- Get current game data tag
	--Set gamehash and game tag to game table
	g_tag = get_gametag()
	if g_tag == 'none' then
		console.log('!!Game not recognized!! Is it not in the database file?')
	end
	data.tags[g_gameinstance] = g_tag

	--If cold start is not set, assume game first boot is true
	if gt_coldstart == nil then
		data.coldstart[g_gameinstance] = true
		gt_coldstart = data.coldstart[g_gameinstance]
	end
	
	--Init first frame after cold start
	g_totalcurvarset = false
	g_coldframe = 0
	
	-- Get collectable var from gametable for tracking
	-- Var 1 current game collected, Var 2 total collected
	gt_gemscollected = data.gemscollected
	gr_gemvarsetup = {get_collectable_ingametable (gt_gemscollected,g_gameinstance)}

	gt_maincollected = data.maincollected
	gr_mainvarsetup = {get_collectable_ingametable (gt_maincollected,g_gameinstance)}

	if g_tag == "spyro2ntsc" then
		gt_s2talismans = gamedata[g_tag].gettalismanvar()
	end



	-- Get health and lives value, set if not empty
	gt_playerhealth = data.playerhealth[g_prevgameinstance]
	gt_playerlives = data.playerlives[g_prevgameinstance]
	if data.playerhealth[g_prevgameinstance] ~= nil then 
		gamedata[g_tag].sethealthvar(gt_playerhealth)
		gamedata[g_tag].setlivesvar(gt_playerlives)
	end

	--Debug
	if 	g_debugconsole == true then
		local gamename = gameinfo.getromname()
		local gamehash = gameinfo.getromhash()
		local playerhealth = gt_playerhealth
		local playerlives = gt_playerlives

		console.log('Game title', gamename)
		console.log('Game hash', gamehash)
		console.log('Game health', playerhealth)
		console.log('Game lives', playerlives)
		-- console.log('before total set in hud', g_totalcurvarset)
	end
end

-- called each frame
function plugin.on_frame(data, settings)

	-- If cold start is true, check level id is within in-game range
	-- Set any values that don't need updating after cold start (lives, health, etc.)

	if gt_coldstart == true then
		local f_levelid = gamedata[g_tag].getlevelidvar()
		if f_levelid >= 10 and f_levelid <= 90 then 
			data.coldstart[g_gameinstance] = false
			gt_coldstart = data.coldstart[g_gameinstance]

			if gt_playerhealth ~= nil then 
				gamedata[g_tag].sethealthvar(gt_playerhealth)
				gamedata[g_tag].setlivesvar(gt_playerlives)
			end
			
			if g_debugconsole == true then 
				console.log('Now in-game, cold start is false') 
			end

			return 	
		end
	end


	-- If cold start is false, then check if collectable value increases afterwards
	if gt_coldstart == false then

		-- Use global var for game data from load fn (gd_curcollectvar, g_tag)
		-- Get init collect, cur collect, and previous frame collect var

		local gdf_gemcollectvar = gamedata[g_tag].getgemvar()
		local gdf_maincollectvar = gamedata[g_tag].getmainvar()
		local gdf_playerlives = gamedata[g_tag].getlivesvar()
		local gdf_playerhealth = gamedata[g_tag].gethealthvar()

		-- Spyro 2 talismans when Spyro 2 is detected
		if g_tag == "spyro2ntsc" then
			gdf_s2talismans = gamedata[g_tag].gettalismanvar()
		end

		
		-- Set cur var to game memory (not HUD)
		-- Initalizes previous frame collectable values
		if g_totalcurvarset == false then
			gamedata[g_tag].setgemvar(gr_gemvarsetup[2])
			gamedata[g_tag].setmainvar(gr_mainvarsetup[2])

			gdf_gemlastcheckcollectvar = gr_gemvarsetup[2]
			gdf_mainlastcheckcollectvar = gr_mainvarsetup[2]
			gdf_playerhealthlastcheckvar = gdf_playerhealth
			gdf_playerliveslastcheckvar = gdf_playerlives

			if g_tag == "spyro2ntsc" then
				gdf_s2talismanslastcheckvar = gdf_s2talismans
				console.log('S2 Talismans',gdf_s2talismanslastcheckvar)
			end


			g_totalcurvarset = true

			if g_debugconsole == true then
				console.log('Collectables set in HUD',g_totalcurvarset)
			end
		end



		-- 3 Get diff between current game gem count 
		-- and total gem count from game table [f_colthisswap] (on update)
		-- Check how many frames has passed since cold start/swap	
		
		if frames_since_restart >= 1 then
			g_coldframe = g_coldframe + 1
		end

		-- Var 2 collected initialy post swap, Var 3 & 4 collected THIS FRAME and PREV FRAME
		-- Outputs array list, total overall collected post swap and delta this frame
		-- (Use for delta collected per frame???)
		r_gemvarupdate = {update_collectable_frame(g_coldframe,gr_gemvarsetup[2],gdf_gemcollectvar,gdf_gemlastcheckcollectvar)}
		r_mainvarupdate = {update_collectable_frame(g_coldframe,gr_mainvarsetup[2],gdf_maincollectvar,gdf_mainlastcheckcollectvar)}


		-- Set HUD var count PER FRAME
		-- Spyro 1 handles the HUD on a per level basis, handled in plug-in
		-- (Why does it count one extra??)
		-- Need to check multiple Spyro 1 tags
		if g_tag == "spyro1ntsc" or g_tag == "spyro1ntsc-j" then
			local f_newgemval = gr_gemvarsetup[2] + r_gemvarupdate[1] - 1
			if f_newgemval <= 0 then f_newgemval = 0 end
			gamedata[g_tag].setgemhuds1var(f_newgemval)
		else
			local f_newgemval = gr_gemvarsetup[2] + r_gemvarupdate[1]
			gamedata[g_tag].setgemhudvar(f_newgemval)
		end
		
		-- Debug
		if g_debugtext == true then
			--gui.drawText(10, 45, string.format("Gems collect for swap: %d", r_gemvarupdate[1]),0xFFFFFFFF, 0xFF000000, 20)
		end
		
	-- Swap trigger check
		if g_coldframe >= 2 then
			-- Run collectable change check, delay so total collect change is set first
			-- Wait until HUD shows total before checking
			-- Check current val is not equal to total, and collected this swap is 0
			-- CANNOT BE PER FRAME FOR MAIN COLLECTABLES OR IT'LL SET IT OFF
			if gdf_maincollectvar ~= gr_mainvarsetup[2] and r_mainvarupdate[1] <= 0 then
				hudupdate = true
				-- console.log(hudupdate)
				-- console.log('current value',r_mainvarupdate[1])
			else
				hudupdate = false
			end
				-- Spyro 2 talismans when Spyro 2 is detected
				if g_tag == "spyro2ntsc" then
					if gdf_s2talismans > gdf_s2talismanslastcheckvar then
						swap_game()
					else
						gdf_s2talismanslastcheckvar = gdf_s2talismans
					end
				end
			--Trigger for when player is damaged and/or dies
			if us_swapondamage == true then
				-- Check when player can take a hit and live
				if gdf_playerhealth >= 0 and gdf_playerhealth <= 4 then
					if gdf_playerhealth < gdf_playerhealthlastcheckvar then
						swap_game()
					else
						gdf_playerhealthlastcheckvar = gdf_playerhealth
					end
				end
				-- Check when player dies and loses a life
				if gdf_playerlives < gdf_playerliveslastcheckvar then
					swap_game()
				else
					gdf_playerliveslastcheckvar = gdf_playerlives
				end
			end

			-- If pre is higher than cur, swap, otherwise set pre to cur on next frame
			-- Currrent check: Main var this swap
			if r_mainvarupdate[1] >= us_mainthreshold and hudupdate == false then
				swap_game()
			else
				gdf_gemlastcheckcollectvar = gdf_gemcollectvar
				gdf_mainlastcheckcollectvar = gdf_maincollectvar
			end



		end
end

	-- Debug
	if g_debugtext == true then

		if gdf_playerhealthlastcheckvar == nil then gdf_playerhealthlastcheckvar = 0 end

		gui.drawText(10, 5, string.format("Player health: %d", gdf_playerhealthlastcheckvar), 0xFFFFFFFF, 0xFF000000, 20)
		gui.drawText(10, 25, string.format("Macguffin threshold: %d", us_mainthreshold),0xFFFFFFFF, 0xFF000000, 20)
		gui.drawText(10, 65, string.format("Game tag: %s", g_tag),0xFFFFFFFF, 0xFF000000, 20)
		gui.drawText(10, 85, string.format("Game instance: %s", g_gameinstance),0xFFFFFFFF, 0xFF000000, 20)
		gui.drawText(10, (client.screenheight() - 40), string.format("Plugin date: %s", plugversion),0xFFFFFFFF, 0xFF000000, 20)
	end
end

-- called each time a game/state is saved (before swap)
function plugin.on_game_save(data, settings)
	
	--Save instance var for next game to fetch
	g_prevgameinstance = config.current_game
	
	-- Add last gem total from game data table and gems collected this swap, add back into table
	-- 4 Add diff gems to REAL gem count (pre-swap)
	local newgemval = gr_gemvarsetup[1] + r_gemvarupdate[1]
	data.gemscollected[g_gameinstance] = newgemval
	
	local newmainval = gr_mainvarsetup[1] + r_mainvarupdate[1]
	data.maincollected[g_gameinstance] = newmainval

	-- Update player health, lives to table, cap at three if player is dead on swap
	local newhealthval = gamedata[g_tag].gethealthvar()
	local newlivesval = gamedata[g_tag].getlivesvar()
	if newhealthval > 3 then
		newhealthval = 3
	end
	data.playerhealth[g_gameinstance] = newhealthval
	data.playerlives[g_gameinstance] = newlivesval


	-- Wait until swap total is updated before next swap var check
	g_totalcurvarset = false
	
	-- Debug
	if g_debugconsole == true then
		local oldgemval = data.gemscollected[g_gameinstance]
		console.log('Before totals set in HUD', g_totalcurvarset)
		-- console.log(oldgemval,r_gemvarupdate[2],newgemval)
		console.log('---')
	end
end

-- called each time a game is marked complete
function plugin.on_complete(data, settings)
end

return plugin

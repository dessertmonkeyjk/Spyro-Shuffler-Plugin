local plugin = {}

plugin.name = "Spyro Shuffler (Debug)"
plugin.author = "dessertmonkeyjk"
plugin.minversion = "2.6.2"
plugin.settings = {
	{ name='gemthreshold', type='number', label='Gems Swap Threshold', default=1 },
}

plugin.description =
[[
	*Version 07-10-2022*
	**DEBUG VERSION! MAY BE UNSTABLE!**

	Swaps games whenever something is collected in-game, as well as syncs collectables across games.
	Only gem and dragon/orb/egg total + hud are synced.
	
	Currently supported

	Spyro 1 NTSC
	Spyro 1 NTSC (Japan)**
	Spryo 2 NTSC
	Spyro 3 NTSC Greatest Hits

	Code Ref
	-gameinfo.getromname returns rom name
	-frames_since_restart returns frames since last swap (shuffler script function)
	-get_tag_from_hash_db returns tag, uses dat file to match key (hash), returns tag (value), dat file contains comments (shuffler script function)

	To-do
	-Rework code so swap trigger & swap total can be set by user (gems, dragon/orb/egg)
		-Put code for triggering based on collectable into function(s)
		-Put code for tracking collectables into function(s) 
			4. (on update) Check for PER FRAME swap threshold (maybe x collected for swap as well but moneybags...)
			5. (pre swap) Add new x collectable gotten to current game in game table
	-Option to have trigger be x collected for current swap, prevent decrease of value by moneybags for trigger purposes
	-Option to switch between x collected PER FRAME or for current swap
]]

-- called once at the start
function plugin.on_setup(data, settings)
	gui.use_surface('client')
	
	data.tags = data.tags or {}
	data.gemscollected = data.gemscollected or {}
	data.maincollected = data.maincollected or {}
	data.coldstart = data.coldstart or {}
end

-- Get game tag 
function get_gametag ()
	local tag = get_tag_from_hash_db(gameinfo.getromhash(), 'plugins/spyro-games-hashes.dat')
	if tag == nil then tag = 'none' end
	return tag
end


-- Solve for x collectable PER FRAME and for current swap, output multiple
function update_collectable_frame (i_coldframe,i_totalcolvar,i_curcolthisframe,i_colcheckedlastframe)
	-- i_coldframe - Frames since cold start
	-- i_curcolthisframe - Collectable value in game this frame
	-- i_colcheckedlastframe - Updated if swap trigger (o_collastframedelta) fails with i_curcolthisframe
	-- i_totalcolvar - Static total collectable from game table
	-- o_collastframedelta - Collectable value colledted in game last frame
	-- o_colthisswap - Collectable value in game this swap


	o_collastframedelta = 0
	o_colthisswap = 0

	if i_coldframe >= 2 then 
		o_collastframedelta = i_curcolthisframe - i_colcheckedlastframe
		o_colthisswap = i_curcolthisframe - i_totalcolvar
	end

	return o_colthisswap,o_collastframedelta
end

function get_collectable_ingametable (i_gametable,i_gamehash)

	-- Unpack table before use?

	-- 1 Get current game gem count from game table [gt_realcollectvar] (on swap)
	if i_gametable[i_gamehash] ~= nil then
		o_gtcollectvar = i_gametable[i_gamehash]
	else
		o_gtcollectvar = 0
	end

	-- 2 Add up current gem total from game table [g_totalcolvar] (on swap)
	-- Add up total collect var so far
	o_gttotalcollectvar = 0
	for key, value in pairs(i_gametable) do 
		o_gttotalcollectvar = o_gttotalcollectvar + value
		-- local gametag = data.tags[key]
		-- console.log(gametag, value)
	end

	return o_gtcollectvar, o_gttotalcollectvar
end

-- Specific functions based on game tag, how to get/set values per game
-- Get Global value, Trigger swap on HUD update
-- Spyro 1 HUD defaults to level gems, can be set to total gems on HUD
-- * = not set yet
local gamedata = {
	['spyro1ntsc']={ 
		-- Spyro the Dragon NTSC [total gems, gem hud, dragon pre/post collect]
		-- HUD (0x077FCC) updates based on global value (0x075750), get Global var for trigger, set both
		getgemvar=function() return mainmemory.read_u16_le(0x075860) end,
		getmainvar=function() return mainmemory.read_u16_le(0x077FCC) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x075860, value) end,
		setgemhuds1var=function(value) return mainmemory.write_u16_le(0x077FC8, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x077FCC,value), mainmemory.write_u16_le(0x075750,value) end
	},
	['spyro1ntsc-j']={ 
		-- Spyro the Dragon Japan [total gems, gem hud*, dragon pre/post collect*]
		-- Gem var not set yet in HUD (need check for spyro 1 specific tags)
		-- Dragon HUD (0x081DCC) updates based on global value (0x07F2C0), get Global var for trigger, set both
		getgemvar=function() return mainmemory.read_u16_le(0x07F3F0) end,
		getmainvar=function() return mainmemory.read_u16_le(0x07F2C0) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x07F3F0, value) end,
		setgemhuds1var=function(value) return mainmemory.write_u16_le(0x081DC8, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x081DCC,value), mainmemory.write_u16_le(0x07F2C0,value) end
	},
	['spyro2ntsc']={ 
		-- Spyro 2 NTSC [total gems, gem hud, orb post collect]
		-- Orb global (0x06702C) is updated right before Orb is given, No idea where the HUD value is stored
		getgemvar=function() return mainmemory.read_u16_le(0x0670CC) end,
		getmainvar=function() return mainmemory.read_u16_le(0x06702C) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x0670CC, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x067660, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x06702C, value) end,
	},
	['spyro3ntsc1-1']={ 
		-- Spyro: Year of the Dragon NTSC [total gems, gem hud, egg post collect]
		-- Egg global updates the HUD, safe to set Global (0x06C740) and trigger with HUD (0x067410)
		getgemvar=function() return mainmemory.read_u16_le(0x06C7FC) end,
		getmainvar=function() return mainmemory.read_u16_le(0x067410) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x06C7FC, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x067368, value) end,
		setmainvar=function(value) return mainmemory.write_u16_le(0x06C740,value) end
	}
}

-- called each time a game/state loads
function plugin.on_game_load(data, settings)
	
	--Get global data
	plugversion='07-10-2022'
	g_gamehash = gameinfo.getromhash()
	gt_coldstart = data.coldstart[g_gamehash]
	us_gemthreshold = settings.gemthreshold

	-- Get current game data tag
	--Set gamehash and game tag to game table
	g_tag = get_gametag()
	if g_tag == 'none' then
		console.log('!!Game not recognized!! Is it not in the database file?')
	end
	data.tags[g_gamehash] = g_tag

	--If cold start is not set, assume game first boot is true
	if gt_coldstart == nil then
		data.coldstart[g_gamehash] = true
		gt_coldstart = data.coldstart[g_gamehash]
	end
	
	--Init first frame after cold start
	g_totalcurverset = false
	g_coldframe = 0
	
	-- Get collectable var from gametable for tracking
	-- Var 1 current game collected, Var 2 total collected
	gt_gemscollected = data.gemscollected
	gr_gemvarsetup = {get_collectable_ingametable (gt_gemscollected,g_gamehash)}

	gt_maincollected = data.maincollected
	gr_mainvarsetup = {get_collectable_ingametable (gt_maincollected,g_gamehash)}

	--Debug
	local gamename = gameinfo.getromname()
	local gamehash = gameinfo.getromhash()
	console.log('Game title', gamename)
	console.log('Game hash', gamehash)
	-- console.log(gr_gemvarsetup[1])
	-- console.log(gr_mainvarsetup[1])
end

-- called each frame
function plugin.on_frame(data, settings)

	--If cold start is true, assume false once gamedata value is at 0
	if gt_coldstart == true then
		if emu.framecount() >= 1600 then 
			data.coldstart[g_gamehash] = false
			gt_coldstart = data.coldstart[g_gamehash]
			
			console.log('Cold start is false')
			return 	
		end
	end
	
	-- If cold start is false, then check if value increases afterwards
	if gt_coldstart == false then

		-- Use global var for game data from load fn (gd_curcollectvar, g_tag)
		-- Get init collect, cur collect, and previous frame collect var

		local gdf_gemcollectvar = gamedata[g_tag].getgemvar()
		local gdf_maincollectvar = gamedata[g_tag].getmainvar()

		
		-- Set cur var to game memory (not HUD)
		-- Run before checking for collectable change, update last checked var
		if g_totalcurverset == false then
			gamedata[g_tag].setgemvar(gr_gemvarsetup[2])
			gamedata[g_tag].setmainvar(gr_mainvarsetup[2])
			
			gdf_gemlastcheckcollectvar = gr_gemvarsetup[2]
			gdf_mainlastcheckcollectvar = gr_mainvarsetup[2]

			g_totalcurverset = true
		end

		-- 3 Get diff between current game gem count 
		-- and total gem count from game table [f_colthisswap] (on update)
		-- Check how many frames has passed since cold start/swap	
		
		if frames_since_restart >= 1 then
			g_coldframe = g_coldframe + 1
		end

		-- Var 1 collected this swap, Var 2 collected THIS FRAME
		r_gemvarupdate = {update_collectable_frame(g_coldframe,gr_gemvarsetup[2],gdf_gemcollectvar,gdf_gemlastcheckcollectvar)}
		r_mainvarupdate = {update_collectable_frame(g_coldframe,gr_mainvarsetup[2],gdf_maincollectvar,gdf_mainlastcheckcollectvar)}


		-- Set HUD var count PER FRAME
		-- Spyro 1 handles the HUD on a per level basis, handled in plug-in
		-- Why does it count one extra??
		-- Need to check multiple Spyro 1 tags
		if g_tag == "spyro1ntsc" then
			local f_newgemval = gr_gemvarsetup[2] + r_gemvarupdate[1] - 1
			if f_newgemval <= 0 then f_newgemval = 0 end
			gamedata[g_tag].setgemhuds1var(f_newgemval)
		else
			local f_newgemval = gr_gemvarsetup[2] + r_gemvarupdate[1]
			gamedata[g_tag].setgemhudvar(f_newgemval)
		end
		
		-- Debug
		gui.drawText(10, 45, string.format("Gems collect for swap: %d", r_gemvarupdate[1]),0xFFFFFFFF, 0xFF000000, 20)
		
	-- Run collect change check, delay so total collect change is set first
		if g_coldframe >= 2 then

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
		
			-- If pre is higher than cur, swap, otherwise set pre to cur on next frame
			-- Currrent check: Main var this swap
			if r_mainvarupdate[1] >= us_gemthreshold and hudupdate == false then
				swap_game()
			else
				gdf_gemlastcheckcollectvar = gdf_gemcollectvar
				gdf_mainlastcheckcollectvar = gdf_maincollectvar
			end
		end
end

	-- Debug
	gui.drawText(10, 5, string.format("Macguffin collected: %d", gr_mainvarsetup[2]), 0xFFFFFFFF, 0xFF000000, 20)
	gui.drawText(10, 25, string.format("Macguffin threshold: %d", us_gemthreshold),0xFFFFFFFF, 0xFF000000, 20)
	gui.drawText(10, 65, string.format("Game tag: %s", g_tag),0xFFFFFFFF, 0xFF000000, 20)
	gui.drawText(10, (client.screenheight() - 40), string.format("Plugin date: %s", plugversion),0xFFFFFFFF, 0xFF000000, 20)
end

-- called each time a game/state is saved (before swap)
function plugin.on_game_save(data, settings)
	
	-- Add last gem total from game data table and gems collected this swap, add back into table
	-- 4 Add diff gems to REAL gem count (pre-swap)
	local newgemval = gr_gemvarsetup[1] + r_gemvarupdate[1]
	data.gemscollected[g_gamehash] = newgemval
	
	local newmainval = gr_mainvarsetup[1] + r_mainvarupdate[1]
	data.maincollected[g_gamehash] = newmainval

	-- Wait until swap total is updated before next swap var check
	g_totalcurverset = false
	
	-- Debug
	local oldgemval = data.gemscollected[g_gamehash]
	console.log('before set', g_totalcurverset)
	-- console.log(oldgemval,r_gemvarupdate[2],newgemval)
	-- console.log('---')
end

-- called each time a game is marked complete
function plugin.on_complete(data, settings)
end

return plugin

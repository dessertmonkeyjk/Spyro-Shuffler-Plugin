local plugin = {}

plugin.name = "Spyro Shuffler"
plugin.author = "dessertmonkeyjk"
plugin.minversion = "2.6.2"
plugin.settings = {}

plugin.description =
[[
	*Version 07-02-2022*

	Swaps games whenever a gem is collected in-game, as well as syncs gems across games.
	Only gem total and hud are synced.
	
	Currently supported

	Spyro 1 NTSC
	Spyro 1 NTSC (Japan)
	Spryo 2 NTSC
	Spyro 3 NTSC Greatest Hits

	Code Ref
	-gameinfo.getromname returns rom name
	-frames_since_restart returns frames since last swap
	-get_tag_from_hash_db returns tag, uses dat file to match key (hash) to name (value), returns tag (middle value)

	To-do
	-Rework code so swap trigger can be set by user (gems, dragon/orb/egg)
	-Rework code so swap total can be set by user (gems, dragon/orb/egg)
	-Fix issue for Spyro 1 HUD losing its mind when setting value to 0
]]

-- called once at the start
function plugin.on_setup(data, settings)
	gui.use_surface('client')
	
	data.tags = data.tags or {}
	data.collectvar = data.collectvar or {}
	data.realcollectvar = data.realcollectvar or {}
	data.coldstart = data.coldstart or {}
end

-- Get game tag 
function get_gametag ()
	local tag = get_tag_from_hash_db(gameinfo.getromhash(), 'plugins/spyro-games-hashes.dat')
	if tag == nil then tag = 'none' end
	return tag
end

-- Specific functions based on game tag, how to get/set values per game
-- Spyro 1 HUD defaults to level gems, can be set to total gems on HUD
-- * = not set yet
local gamedata = {
	['spyro1ntsc']={ -- Spyro the Dragon NTSC [total gems, gem hud*, dragon post collect]
		getgemvar=function() return mainmemory.read_u16_le(0x075860) end,
		getmainvar=function() return mainmemory.read_u16_le(0x077FCC) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x075860, value) end,
		setgemhuds1var=function(value) return mainmemory.write_u16_le(0x077FC8, value) end
	},
	['spyro1jntsc']={ -- Spyro the Dragon J [total gems, gem hud*, dragon post collect*]
		getgemvar=function() return mainmemory.read_u16_le(0x07F3F0) end,
		getmainvar=function() return mainmemory.read_u16_le(0x077FCC) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x07F3F0, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x075860, value) end
	},
	['spyro2ntsc']={ -- Spyro 2 NTSC [total gems, gem hud*, orb post collect*]
		getgemvar=function() return mainmemory.read_u16_le(0x0670CC) end,
		getmainvar=function() return mainmemory.read_u16_le(0x0670CC) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x0670CC, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x067660, value) end
	},
	['spyro3ntsc']={ -- Spyro: Year of the Dragon NTSC [total gems, gem hud*, egg post collect]
		getgemvar=function() return mainmemory.read_u16_le(0x06C7FC) end,
		getmainvar=function() return mainmemory.read_u16_le(0x067410) end,
		setgemvar=function(value) return mainmemory.write_u16_le(0x06C7FC, value) end,
		setgemhudvar=function(value) return mainmemory.write_u16_le(0x067368, value) end
	}
}

-- called each time a game/state loads
function plugin.on_game_load(data, settings)
	
	--Get global data
	local gt_coldstart = data.coldstart[gameinfo.getromhash()]
	g_colthreshold = 5
	
	--If cold start is not set, assume game first boot is true
	if gt_coldstart == nil then
		data.coldstart[gameinfo.getromhash()] = true
	end
	
	--Init first frame after cold start
	g_coldframe = 0
	
	-- Get current game data, get real value, override after, set back before swap
	g_tag = get_gametag()
	if g_tag == 'none' then
		console.log('!!Game not recognized!! Is it not in the database file?')
	end
	
	-- 1 Get current game gem count from game table [gt_realcollectvar] (on swap)

	if data.collectvar[gameinfo.getromhash()] ~= nil then
		gt_realcollectvar = data.collectvar[gameinfo.getromhash()]
	else
		gt_realcollectvar = 0
	end

	-- 2 Add up current gem total from game table [g_totalcolvar] (on swap)
	-- Add up total collect var so far
	g_totalcolvar = 0
	-- g_displaycollectdelta = 0
	for key, value in pairs(data.collectvar) do 
		g_totalcolvar = g_totalcolvar + value
		local gametag = data.tags[key]
		console.log(gametag, value)
	end

	-- Store initial collect value
	gdf_lastcheckcollectvar = gd_curcollectvar
	f_totalcurverset = false
	
	--Set global gamedata for current game
	data.tags[gameinfo.getromhash()] = g_tag
	
	--Debug
	local gamename = gameinfo.getromname()
	local gamehash = gameinfo.getromhash()
	console.log('Game title', gamename)
	console.log('Game hash', gamehash)

end

-- called each frame
function plugin.on_frame(data, settings)
	--Get global data
	local gt_coldstart = data.coldstart[gameinfo.getromhash()]

	--If cold start is true, assume false once gamedata value is at 0
	if gt_coldstart == true then
		if emu.framecount() >= 1600 then 
			data.coldstart[gameinfo.getromhash()] = false
			gt_coldstart = data.coldstart[gameinfo.getromhash()]
			
			console.log('Cold start is false')
			return 	
		end
	end

	--Use global var for game data from load fn (gd_curcollectvar, g_tag)
	-- Get init collect, cur collect, and previous frame collect var
	local gdf_curcollectvar = gamedata[g_tag].getgemvar()
	
	-- If cold start is false, then check if value increases afterwards
	if gt_coldstart == false then

		fcolvardelta = 0
		fdeltacollectvar = 0
		
		-- Set cur var to game memory (not HUD)
		-- Run before checking for gem change, update last checked var
		
		if f_totalcurverset == false then
			local f_newgemval = g_totalcolvar + fdeltacollectvar
			gamedata[g_tag].setgemvar(g_totalcolvar)
			
			gdf_lastcheckcollectvar = g_totalcolvar
			f_totalcurverset = true
		end
		
		-- 3 Get diff between current game gem count 
		-- and total gem count from game table [fdeltacollectvar] (on update)
		-- Check how many frames has passed since cold start/swap	
		
		if frames_since_restart >= 1 then
			g_coldframe = g_coldframe + 1
		end
		
		if g_coldframe >= 2 then 
			fcolvardelta = gdf_curcollectvar - gdf_lastcheckcollectvar
			fdeltacollectvar = gdf_curcollectvar - g_totalcolvar	
		end

		-- Set HUD gem count PER FRAME
		-- Spyro 1 handles the HUD on a per level basis, handled in plug-in
			-- 	Why does it count one extra??
		-- Need to check multiple Spyro 1 tags
		if g_tag == "spyro1ntsc" then
			local f_newgemval = g_totalcolvar + fdeltacollectvar - 1
			if f_newgemval <= 0 then f_newgemval = 0 end
			gamedata[g_tag].setgemhuds1var(f_newgemval)
		else
			local f_newgemval = g_totalcolvar + fdeltacollectvar
			gamedata[g_tag].setgemhudvar(f_newgemval)
		end
		
		-- Debug
		-- gui.drawText(10, 20, string.format("Var collect for swap: %d", fdeltacollectvar),0xFFFFFFFF, 0xFF000000, 16)
	

		
	-- Run collect change check, delay so total collect change is set first
		if g_coldframe >= 2 then
			-- If pre is higher than cur, swap, otherwise set pre to cur on next frame
			if fcolvardelta == g_colthreshold then
				swap_game()
			else
				gdf_lastcheckcollectvar = gdf_curcollectvar
			end
		end
end

	-- Debug
	-- gui.drawText(10, 5, string.format("Var collected: %d", g_totalcolvar), 0xFFFFFFFF, 0xFF000000, 16)
	gui.drawText(10, 35, string.format("Gem threshold: %d", g_colthreshold),0xFFFFFFFF, 0xFF000000, 16)
	gui.drawText(10, 50, string.format("Game tag: %s", g_tag),0xFFFFFFFF, 0xFF000000, 16)
	
end

-- called each time a game/state is saved (before swap)
function plugin.on_game_save(data, settings)

	local oldgemval = data.collectvar[gameinfo.getromhash()]
	
	-- Add last gem total from game data table and gems collected this swap, add back into table
	-- 4 Add diff gems to REAL gem count (pre-swap)
	local newgemval = gt_realcollectvar + fdeltacollectvar
	data.collectvar[gameinfo.getromhash()] = newgemval
	
	-- Wait until swap total is updated before next swap var check
	f_totalcurverset = false
	
	-- Debug
	console.log('before set', f_totalcurverset)
	-- console.log(oldgemval,fdeltacollectvar,newgemval)
	-- console.log('---')
end

-- called each time a game is marked complete
function plugin.on_complete(data, settings)
end

return plugin

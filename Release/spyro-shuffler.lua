local plugin = {}

plugin.name = "Spyro Shuffler"
plugin.author = "dessertmonkeyjk"
plugin.minversion = "2.6.2"
plugin.settings = {}

plugin.description =
[[
	*Version 07-03-2022*

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
	-Rework code so swap trigger & swap total can be set by user (gems, dragon/orb/egg)
		-Push code for triggering based on collectable into function(s)
		-Put code for tracking collectables into function(s) 
			1. (on swap) Get static x collectable count for current game from game table
			2. (on swap) Add static total for all games x collectables from game table (for diff, HUD sync)
			3. (on update) Get x collectable delta PER FRAME and for current swap
			4. (on update) Check for PER FRAME swap threshold (maybe x collected for swap as well but moneybags...)
			5. (pre swap) Add new x collectable gotten to current game in game table
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
	g_gamehash = gameinfo.getromhash()
	gt_coldstart = data.coldstart[g_gamehash]
	g_colthreshold = 5

	-- Get current game data tag
	g_tag = get_gametag()
	if g_tag == 'none' then
		console.log('!!Game not recognized!! Is it not in the database file?')
	end
	
	--Set gamehash and game tag to game table
	data.tags[g_gamehash] = g_tag

	--If cold start is not set, assume game first boot is true
	if gt_coldstart == nil then
		data.coldstart[g_gamehash] = true
		gt_coldstart = data.coldstart[g_gamehash]
	end
	
	--Init first frame after cold start
	g_totalcurverset = false
	g_coldframe = 0
	
	-- 1 Get current game gem count from game table [gt_realcollectvar] (on swap)
	if data.collectvar[g_gamehash] ~= nil then
		gt_realcollectvar = data.collectvar[g_gamehash]
	else
		gt_realcollectvar = 0
	end

	-- 2 Add up current gem total from game table [g_totalcolvar] (on swap)
	-- Add up total collect var so far
	g_totalcolvar = 0
	for key, value in pairs(data.collectvar) do 
		g_totalcolvar = g_totalcolvar + value
		local gametag = data.tags[key]
		console.log(gametag, value)
	end
	
	--Debug
	local gamename = gameinfo.getromname()
	local gamehash = gameinfo.getromhash()
	console.log('Game title', gamename)
	console.log('Game hash', gamehash)

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

		-- f_collastframedelta - Diff PER FRAME for x collectable pickup, used for threshold (always resets to 0)
		-- f_colthisswap - Tracks how many x collectable gotten this swap, added to game table later pre-swap

		-- Use global var for game data from load fn (gd_curcollectvar, g_tag)
		-- Get init collect, cur collect, and previous frame collect var

		local gdf_curcollectvar = gamedata[g_tag].getgemvar()
		local f_collastframedelta = 0
		f_colthisswap = 0
		
		-- Set cur var to game memory (not HUD)
		-- Run before checking for gem change, update last checked var
		
		if g_totalcurverset == false then
			gamedata[g_tag].setgemvar(g_totalcolvar)
			
			gdf_lastcheckcollectvar = g_totalcolvar
			g_totalcurverset = true
		end
		
		-- 3 Get diff between current game gem count 
		-- and total gem count from game table [f_colthisswap] (on update)
		-- Check how many frames has passed since cold start/swap	
		
		if frames_since_restart >= 1 then
			g_coldframe = g_coldframe + 1
		end
		
		if g_coldframe >= 2 then 
			f_collastframedelta = gdf_curcollectvar - gdf_lastcheckcollectvar
			f_colthisswap = gdf_curcollectvar - g_totalcolvar	
		end

		-- Set HUD gem count PER FRAME
		-- Spyro 1 handles the HUD on a per level basis, handled in plug-in
			-- 	Why does it count one extra??
		-- Need to check multiple Spyro 1 tags
		if g_tag == "spyro1ntsc" then
			local f_newgemval = g_totalcolvar + f_colthisswap - 1
			if f_newgemval <= 0 then f_newgemval = 0 end
			gamedata[g_tag].setgemhuds1var(f_newgemval)
		else
			local f_newgemval = g_totalcolvar + f_colthisswap
			gamedata[g_tag].setgemhudvar(f_newgemval)
		end
		
		-- Debug
		gui.drawText(10, 20, string.format("Var collect for swap: %d", f_colthisswap),0xFFFFFFFF, 0xFF000000, 16)
		
	-- Run collect change check, delay so total collect change is set first
		if g_coldframe >= 2 then
			-- If pre is higher than cur, swap, otherwise set pre to cur on next frame
			if f_collastframedelta >= g_colthreshold then
				swap_game()
			else
				gdf_lastcheckcollectvar = gdf_curcollectvar
			end
		end
end

	-- Debug
	gui.drawText(10, 5, string.format("Var collected: %d", g_totalcolvar), 0xFFFFFFFF, 0xFF000000, 16)
	gui.drawText(10, 35, string.format("Gem threshold: %d", g_colthreshold),0xFFFFFFFF, 0xFF000000, 16)
	gui.drawText(10, 50, string.format("Game tag: %s", g_tag),0xFFFFFFFF, 0xFF000000, 16)
	
end

-- called each time a game/state is saved (before swap)
function plugin.on_game_save(data, settings)
	
	-- Add last gem total from game data table and gems collected this swap, add back into table
	-- 4 Add diff gems to REAL gem count (pre-swap)
	local newgemval = gt_realcollectvar + f_colthisswap
	data.collectvar[g_gamehash] = newgemval
	
	-- Wait until swap total is updated before next swap var check
	g_totalcurverset = false
	
	-- Debug
	local oldgemval = data.collectvar[g_gamehash]
	console.log('before set', g_totalcurverset)
	-- console.log(oldgemval,f_colthisswap,newgemval)
	-- console.log('---')
end

-- called each time a game is marked complete
function plugin.on_complete(data, settings)
end

return plugin

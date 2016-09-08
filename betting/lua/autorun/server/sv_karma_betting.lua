-- Made by Luk
-- http://steamcommunity.com/id/doctorluk/
-- Version: 1.0

if SERVER then

	function karmabet_CheckForWin()
		if GAMEMODE.MapWin == WIN_TRAITOR or GAMEMODE.MapWin == WIN_INNOCENT then
			local mw = GAMEMODE.MapWin
			GAMEMODE.MapWin = WIN_NONE
			return mw
		end
	
		local traitor_alive = false
		local innocent_alive = false
		for k,v in pairs(player.GetAll()) do
			if v:Alive() and v:IsTerror() then
				if v:GetTraitor() then
					traitor_alive = true
				else
				innocent_alive = true
				end
			end

			if traitor_alive and innocent_alive then
				return WIN_NONE
			end
		end

		if traitor_alive and not innocent_alive then
			return WIN_TRAITOR
		elseif not traitor_alive and innocent_alive then
			return WIN_INNOCENT
		elseif not innocent_alive then
			return WIN_TRAITOR
		end

		return WIN_NONE
	end
	
	KARMABET_CAN_BET = true
	
	t_bet_total = 0
	i_bet_total = 0
	tbl_betters = {}
	tbl_results = {}
	karmabet_winner = ""
	
	-- Used to communicate with clients
	util.AddNetworkString( "karmabet_updatehud" )
	
	-- Show given player a predesigned error message
	function karmabet_reportError( ply, errormsg )
		ULib.tsayColor( ply, true,
			Color( 50, 50, 50, 255 ), "[", 
			Color( 190, 40, 40, 255 ), "Karmabet",
			Color( 50, 50, 50, 255 ), "] ", Color( 255, 0, 0, 255 ), "ERROR: ",
			Color( 255, 255, 0, 0 ), errormsg )
	end
	
	-- Show given player a predesigned notice message
	function karmabet_reportNotice( ply, note )
		ULib.tsayColor( ply, true,
			Color( 50, 50, 50, 255 ), "[", 
			Color( 190, 40, 40, 255 ), "Karmabet",
			Color( 50, 50, 50, 255 ), "] ",
			Color( 100, 100, 255, 255 ), "NOTICE: ",
			Color( 255, 255, 0, 0 ), note )
	end
	
	-- Show spectating/dead players that someone has placed a bet
	function karmabet_echoBetPlacement( ply, amount, target )
	
		local color = Color( 0, 255, 0, 255 )
		if target == "innocent" then
			target = "Innocent"
		else
			target = "Traitor"
			color = Color( 255, 0, 0, 255 )
		end
		
		for _, player in ipairs( player.GetHumans() ) do
			if not player:Alive() or player:IsSpec() then
				ULib.tsayColor( player, true,
				Color( 50, 50, 50, 255 ), "[", 
				Color( 190, 40, 40, 255 ), "Karmabet",
				Color( 50, 50, 50, 255 ), "] ", 
				Color( 255, 255, 0, 0 ), ply:Nick(),
				Color( 60, 90, 100, 255 ), " wettet ",
				Color( 190, 40, 40, 255), amount .. "",	
				Color( 60, 90, 100, 255 ), " Karma auf das Team ", 
				color, target .. "")
			end
		end
		
	end
	
	-- Big check whether or not someone can bet
	function karmabet_canBet( calling_ply, amount, target )
	
		if not calling_ply then return false end
	
		-- Only dead/spectating players are allowed to bet
		if calling_ply:Alive() and not calling_ply:IsSpec() then
			karmabet_reportError( calling_ply, "Du kannst nur wetten, wenn du nicht lebst!" )
			return false
		end
		
		-- Only allow betting while a round is active
		if GetRoundState() ~= ROUND_ACTIVE then
			karmabet_reportError( calling_ply, "Man kann nur während einer aktiven Runde wetten!" )
			return false
		end
		
		-- Prevent betting when betting is disabled
		if not KARMABET_CAN_BET or KARMABET_HAS_RUN then
			karmabet_reportError( calling_ply, "Zeit zum Wetten ist abgelaufen!" )
			return false
		end
		
		-- Check for valid team
		target = string.lower( target )
		if target == "t" or target == "traitor" then
			target = "traitor"
		elseif target == "i" or target == "inno" or target == "innocent" then
			target = "innocent"
		else
			karmabet_reportError( calling_ply, "Du hast kein Ziel eingegeben! Versuche T oder I für Traitor oder Innocent." )
			return false
		end
		
		-- Check if player has enough karma to bet
		if calling_ply:GetLiveKarma() < KARMABET_MINIMUM_LIVE_KARMA then
			karmabet_reportError( calling_ply, "Dein Karma ist zu gering um zu wetten!" )
			return false
		end
		
		-- Reduce bet depending on how much Karma the player has left
		if calling_ply:GetLiveKarma() - amount < KARMABET_MINIMUM_LIVE_KARMA then
			amount = math.floor( calling_ply:GetLiveKarma() - KARMABET_MINIMUM_LIVE_KARMA )
			if amount == 0 then
				karmabet_reportError( calling_ply, "Dein verbleibendes Karma ist zu gering um zu wetten!" )
				return false
			end
			karmabet_reportNotice( calling_ply, "Dein Karma ist low! Es konnte nur " .. amount .. " Karma gesetzt werden!" )
		end
		
		-- Check if player changed his mind about voting or limit is reached
		local tmptable = tbl_betters[calling_ply:SteamID()]
		if tmptable then
			local saved_amount = tmptable[1]
			local saved_target = tmptable[2]
			
			-- Only allow betting for the same team again
			if saved_target ~= target then
				karmabet_reportError( calling_ply, "Du kannst nur dem gleichen Team mehr wetten und nicht mehr wechseln!" )
				return false
			end
			
			-- Limit new amount to maximum
			local maxAdd = KARMABET_MAXIMUM_KARMA - saved_amount
			if amount > maxAdd then
				amount = maxAdd
			end
			
			-- Report hit maximum
			if amount == 0 then
				karmabet_reportError( calling_ply, "Du kannst nicht mehr als " .. KARMABET_MAXIMUM_KARMA .. " wetten!" )
				return false
			end
			
			-- Update player's saved amount
			local new_saved_amount = amount + saved_amount
			tbl_betters[calling_ply:SteamID()] = { new_saved_amount, target }
		end
		
		-- If all passes, start bet
		karmabet_start( calling_ply, amount, target )
		
		return true
	end
	
	-- Actually start the bet
	function karmabet_start( calling_ply, amount, target )
	
		-- Reduce player's karma by the amount he bet
		calling_ply:SetLiveKarma( calling_ply:GetLiveKarma() - amount )
		
		local amountSending = 0
		
		-- Add to global counter
		if target == "traitor" then
			t_bet_total = t_bet_total + amount
			amountSending = t_bet_total
		else
			i_bet_total = i_bet_total + amount
			amountSending = i_bet_total
		end
		
		-- Add player to table of players who have placed a bet
		if not tbl_betters[calling_ply:SteamID()] then
			tbl_betters[calling_ply:SteamID()] = { amount, target }
		end
		PrintTable( tbl_betters )
		
		karmabet_echoBetPlacement( calling_ply, amount, target )
		karmabet_updateAllPlayers()
		
	end
	
	-- Lazy refresh of running bets
	function karmabet_refresh()
	
		local bet_i = 0
		local bet_t = 0
		
		for _, entry in pairs( tbl_betters ) do
		
			if entry[2] == "traitor" then
				bet_t = entry[1] + bet_t
			elseif entry[2] == "innocent" then
				bet_i = entry[1] + bet_i
			end
			
		end
		
		t_bet_total = bet_t
		i_bet_total = bet_i
		
		karmabet_updateAllPlayers()
		
	end
	
	-- Update the display for all players
	function karmabet_updateAllPlayers()
	
		local allplayers = player.GetHumans()
		
		for _, player in ipairs( allplayers ) do
		
			net.Start( "karmabet_updatehud" )
			net.WriteInt( t_bet_total, 32 )
			net.WriteString( "traitor" )
			net.Send( player )
			
			net.Start( "karmabet_updatehud" )
			net.WriteInt( i_bet_total, 32 )
			net.WriteString( "innocent" )
			net.Send( player )
			
		end
		
	end
	
	function karmabet_timedBettingEnd()
	
		KARMABET_CAN_BET = true
		KARMABET_HAS_RUN = false
		table.Empty( tbl_results )
		karmabet_winner = ""
		
		ServerLog("[Karmabet] Bets open!\n")
		
		timer.Create( "karmabet_timer_timewarning", KARMABET_BET_TIME - 20, 1, function()
		
			ULib.tsayColor( nil, false,
				Color( 50, 50, 50, 255 ), "[", 
				Color( 190, 40, 40, 255 ), "Karmabet",
				Color( 50, 50, 50, 255 ), "] ", 
				Color( 255, 255, 0, 0 ), "Noch 20 Sekunden um zu wetten!" )
			
		end )
		
		timer.Create( "karmabet_timer", KARMABET_BET_TIME, 1, function()
		
			ULib.tsayColor( nil, false,
				Color( 50, 50, 50, 255 ), "[", 
				Color( 190, 40, 40, 255 ), "Karmabet",
				Color( 50, 50, 50, 255 ), "] ", 
				Color( 255, 255, 0, 0 ), "Wetten geschlossen!" )
			
			KARMABET_CAN_BET = false
			ServerLog("[Karmabet] Bets closed!\n")
			
		end )
	end
	hook.Add( "TTTBeginRound", "karmabet_timedBettingEnd", karmabet_timedBettingEnd )
	
	-- Act after a round has ended
	function karmabet_onPotentialEnd( callback_data )
	
		timer.Simple( 0.005, function()	
		
			if GetRoundState() == ROUND_ACTIVE or isnumber( callback_data ) and not KARMABET_HAS_RUN then
			
				if karmabet_CheckForWin() == WIN_NONE then return end
			
				KARMABET_HAS_RUN = true
				
				timer.Remove( "karmabet_timer_timewarning" )
				timer.Remove( "karmabet_timer" )
				
				if isnumber(callback_data) then
					ServerLog("TIMER KILLED + ROUND END!!\n")
				else
					ServerLog("TIMER KILLED + DEATH EVENT!!\n")
				end
				
				local winner = "innocent"
				local loser_amount = t_bet_total
				
				if result == WIN_TRAITOR then
					winner = "traitor"
					loser_amount = i_bet_total
				end
				
				karmabet_winner = winner
				
				-- PrintTable( tbl_betters )
				
				-- Winners get their bet, and a bonus depending on the amount of bets against them				
				for id, entry in pairs( tbl_betters ) do
				
					local ply = player.GetBySteamID( id )
					if ply then
						local amount = entry[1]
						local target = entry[2]
						
						if target == winner then
						
							local karmaReturned = math.ceil( amount + ( amount * (math.random(10, 25) / 100) ) + ( loser_amount * (math.random(5, 15) / 100) ) )
							
							tbl_results[id] = { karmaReturned, target }
							
							ULib.tsayColor( nil, false,
								Color( 50, 50, 50, 255 ), "[", 
								Color( 190, 40, 40, 255), "Karmabet",
								Color( 50, 50, 50, 255), "] ",
								Color( 255, 255, 0, 0 ), ply:Nick(),
								Color( 0, 255, 0, 255), " gewinnt ",
								Color( 255, 255, 255, 255), karmaReturned .. "",
								Color( 0, 255, 0, 255), " Karma!" )
							
							local newKarma = ply:GetLiveKarma() + karmaReturned
							if newKarma > 1000 then
								newKarma = 1000
							end
							ply:SetBaseKarma( newKarma )
							ply:SetLiveKarma( newKarma )
							
						else
						
							ULib.tsayColor( nil, false,
							Color( 50, 50, 50, 255 ), "[", 
							Color( 190, 40, 40, 255), "Karmabet",
							Color( 50, 50, 50, 255), "] ",
							Color( 255, 255, 0, 0 ), ply:Nick(),
							Color( 255, 0, 0, 255), " verliert ",
							Color( 255, 255, 255, 255), amount .. "",
							Color( 255, 0, 0, 255), " Karma!" )
							
							tbl_results[id] = { amount, target }
						end
					end
				end
				
				-- PrintTable( tbl_results )
				karmabet_insertResultsMySQL()
				
				table.Empty(tbl_betters)
				karmabet_refresh()

				-- Since we run our Hook AFTER karma has been saved, we have to save it again, otherwise the gained karma
				-- is lost upon mapchange
				KARMA.Rebase()
				KARMA.RememberAll()
			end
		end)
	end
	hook.Add( "PlayerDeath", "karmabet_onPotentialEnd", karmabet_onPotentialEnd )
	hook.Add( "TTTRoundEnd", "karmabet_onPotentialEnd", karmabet_onPotentialEnd )
	
	-- Send new player current bets
	function karmabet_onPlayerConnect( ply )
		net.Start( "karmabet_updatehud" )
		net.WriteInt( t_bet_total, 32 )
		net.WriteString( "traitor" )
		net.Send( ply )
		
		net.Start( "karmabet_updatehud" )
		net.WriteInt( i_bet_total, 32 )
		net.WriteString( "innocent" )
		net.Send( ply )
	end
	hook.Add( "PlayerInitialSpawn", "karmabet_onPlayerConnect", karmabet_onPlayerConnect )
	
	-- Remove disconnected player from bets and update
	-- function karmabet_onPlayerDisconnect( ply )
		-- tbl_betters[ply:SteamID()] = nil
		-- karmabet_refresh()
	-- end
	-- hook.Add( "PlayerDisconnected", "karmabet_onPlayerDisconnect", karmabet_onPlayerDisconnect )
	
	-- Disable !bet chat text
	hook.Add( "PlayerSay", "KarmabetChatPrevention", function( ply, text, team )
		text = string.lower(text)
		if ( string.sub( text, 1, 4 ) == "!bet" or string.sub( text, 1, 7 ) == "!mybets" ) then
			return ""
		end
	end )
	
end
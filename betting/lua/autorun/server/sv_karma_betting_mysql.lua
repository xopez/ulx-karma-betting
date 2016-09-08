-- Made by Luk
-- http://steamcommunity.com/id/doctorluk/
-- Version: 1.0
if SERVER then
	
	if not KARMABET_USE_MYSQL then return end
	
	require( "mysqloo" )
	
	--
	--	DATABASE CONFIGURATION
	--
	local DATABASE_HOST = ""
	local DATABASE_USERNAME = ""
	local DATABASE_PASSWORD = ""
	local DATABASE_PORT = 3306
	local DATABASE_NAME = ""

	local queue = {}

	local db = mysqloo.connect( DATABASE_HOST, DATABASE_USERNAME, DATABASE_PASSWORD, DATABASE_NAME, DATABASE_PORT )

	local function query( str, callback )
		local q = db:query( str )
		
		function q:onSuccess( data )
			if callback ~= nil then
				callback( data )
			end
		end
		
		function q:onError( err )
			if db:status() == mysqloo.DATABASE_NOT_CONNECTED then
				table.insert( queue, { str, callback } )
				db:connect()
			return end
			
			print( "[Karmabet] Error! Query failed: " .. err )
		end
		
		q:start()
	end

	function db:onConnected()
		print( "[Karmabet] Connected to MySQL." )
		
		query( "SET NAMES 'utf8';" )
		query( "CREATE TABLE IF NOT EXISTS karmabet (id int(32) unsigned NOT NULL AUTO_INCREMENT, bet_id int(32) unsigned NOT NULL, name text COLLATE utf8_unicode_ci NOT NULL, steamid text COLLATE utf8_unicode_ci NOT NULL, amount int(11) NOT NULL, date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id)) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1;" )
		
		for k, v in pairs( queue ) do
			query( v[ 1 ], v[ 2 ] )
		end
		
		queue = {}
	end

	function db:onConnectionFailed( err )
		print( "[Karmabet] Database connection failed: " .. err )
	end

	db:connect()
	
	-- Shows the five highest entries in the database
	function karmabet_showMyBetSummary( ply, steamid )
		query( "SELECT sum(amount) as total FROM `karmabet` WHERE date >= DATE_SUB(NOW(), INTERVAL 7 DAY) AND steamid = '" .. db:escape(steamid) .. "' LIMIT 1", function( list )
			
			PrintTable(list)
					
			for k, v in ipairs( list ) do
				if #list == 0 or not tonumber(v.total) then
					ULib.tsayColor( ply, true,
						Color( 50, 50, 50, 255 ), "[", 
						Color( 190, 40, 40, 255 ), "Karmabet",
						Color( 50, 50, 50, 255 ), "] ",
						Color( 255, 255, 0, 255 ), "Leider keine Einträge gefunden!")
					return
				end
				
				if tonumber(v.total) >= 0 then
					ULib.tsayColor( ply, true,
						Color( 50, 50, 50, 255 ), "[", 
						Color( 190, 40, 40, 255 ), "Karmabet",
						Color( 50, 50, 50, 255 ), "] ",
						Color( 255, 255, 255, 255 ), "Deine Wettbalance: ",
						Color( 0, 255, 0, 255 ), v.total .. " ",
						Color( 255, 255, 255, 255 ), "Karma!" )
				else
					ULib.tsayColor( ply, true,
						Color( 50, 50, 50, 255 ), "[", 
						Color( 190, 40, 40, 255 ), "Karmabet",
						Color( 50, 50, 50, 255 ), "] ",
						Color( 255, 255, 255, 255 ), "Deine Wettbalance: ",
						Color( 255, 0, 0, 255 ), v.total .. " ",
						Color( 255, 255, 255, 255 ), "Karma!" )
				end
			end
		end)
	end
	
	-- Shows the five highest entries in the database
	function karmabet_showBestBetters( duration )
		query( "SELECT name, sum(amount) as total FROM `karmabet` WHERE date >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY steamid HAVING sum(amount) > 0 ORDER BY total DESC LIMIT 5", function( list )
			
			PrintTable(list)
		
			if #list == 0 then
				ULib.tsayColor( nil, true,
					Color( 50, 50, 50, 255 ), "[", 
					Color( 190, 40, 40, 255 ), "Karmabet",
					Color( 50, 50, 50, 255 ), "] ",
					Color( 255, 255, 0, 255 ), "Leider keine Einträge gefunden!")
				return
			end
			
			ULib.tsayColor( nil, true,
					Color( 50, 50, 50, 255 ), "[", 
					Color( 190, 40, 40, 255 ), "Karmabet",
					Color( 50, 50, 50, 255 ), "] ",
					Color( 255, 255, 0, 255 ), "Die ", 
					Color( 0, 255, 0, 255 ), "besten ",
					Color( 255, 255, 255, 255 ), #list .. " ",
					Color( 255, 255, 0, 255 ), "Wetthelden: " )
					
			for k, v in ipairs( list ) do
				ULib.tsayColor( nil, true,
					Color( 50, 50, 50, 255 ), "[", 
					Color( 190, 40, 40, 255 ), "Karmabet",
					Color( 50, 50, 50, 255 ), "] ",
					Color( 0, 255, 0, 255 ), "#" .. k .. ": ",
					Color( 255, 255, 0, 255 ), v.name .. " ",
					Color( 255, 255, 255, 255 ), "mit ",
					Color( 0, 255, 0, 255 ), v.total .. " ",
					Color( 255, 255, 255, 255 ), "Karma!" )
			end
		end)
	end
	
	function karmabet_showWorstBetters( duration )
		query( "SELECT name, sum(amount) as total FROM `karmabet` WHERE date >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY steamid HAVING sum(amount) < 0 ORDER BY total ASC LIMIT 5", function( list )
			
			PrintTable(list)
		
			if #list == 0 then
				ULib.tsayColor( nil, true,
					Color( 50, 50, 50, 255 ), "[", 
					Color( 190, 40, 40, 255 ), "Karmabet",
					Color( 50, 50, 50, 255 ), "] ",
					Color( 255, 255, 0, 255 ), "Leider keine Einträge gefunden!")
				return
			end
			
			ULib.tsayColor( nil, true,
					Color( 50, 50, 50, 255 ), "[", 
					Color( 190, 40, 40, 255 ), "Karmabet",
					Color( 50, 50, 50, 255 ), "] ",
					Color( 255, 255, 0, 255 ), "Die ", 
					Color( 255, 0, 0, 255 ), "schlechtesten ",
					Color( 255, 255, 255, 255 ), #list .. " ",
					Color( 255, 255, 0, 255 ), "Wettnoobs: " )
					
			for k, v in ipairs( list ) do
				ULib.tsayColor( nil, true,
					Color( 50, 50, 50, 255 ), "[", 
					Color( 190, 40, 40, 255 ), "Karmabet",
					Color( 50, 50, 50, 255 ), "] ",
					Color( 255, 0, 0, 255 ), "#" .. k .. ": ",
					Color( 255, 255, 0, 255 ), v.name .. " ",
					Color( 255, 255, 255, 255 ), "mit ",
					Color( 255, 0, 0, 255 ), v.total .. " ",
					Color( 255, 255, 255, 255 ), "Karma!" )
			end
		end)
	end
	
	function karmabet_insertResultsMySQL()
		--[[
		Database Structure:
		1: id
		2: bet_id
		3: steamid
		4: amount
		5: date
		INSERT INTO karmabet(`bet_id`, `name`, `steamid`, `amount`)	VALUES( bet_id, 'name', 'steamid', amount), ( bet_id .....);
		...
		]]--
		
		query( "SELECT MAX(bet_id) + 1 as last_betid FROM karmabet WHERE 1 LIMIT 1", function( data )
			
			PrintTable(data) 
			
			-- Set default bet_id to 1 if table is empty
			local bet_id = 1
			
			-- Extract latest bet_id from table
			if data[1].last_betid then
				bet_id = data[1].last_betid
			end
			
			local loops = 0
			local querystr = "INSERT INTO `" .. DATABASE_NAME .. "`.`karmabet` (`bet_id`, `name`, `steamid`, `amount`) VALUES("
			
			PrintTable( tbl_results )
			-- Go through the table of karmabet participants and construct the SQL-String
			for id, entry in pairs( tbl_results ) do
			
				local ply = player.GetBySteamID( id )
				if ply then 
					local amount = entry[1]
					local target = entry[2]
					
					if loops > 0 then
						querystr = querystr .. ", ("
					end
						
					if target == karmabet_winner then
						querystr = querystr
						.. bet_id .. ", '" 
						.. db:escape( ply:Nick() ) .. "', '" 
						.. db:escape( id ) .. "', " 
						.. amount .. ")"
					else
						querystr = querystr
						.. bet_id .. ", '" 
						.. db:escape( ply:Nick() ) .. "', '" 
						.. db:escape( id ) .. "', " 
						.. (-1 * amount) .. ")"
					end
					
					loops = loops + 1
				end
			end
			querystr = querystr .. ";"
			ServerLog("[Karmabet] Query String: " .. querystr .. "\n")
			
			if loops == 0 then return end
			
			query( querystr )
			
		end )
	end 

end
require 'moonloader'
require 'sampfuncs'

--License: GNU-3.0 (https://github.com/d7KrEoL/rustlerFireFixSAMP?tab=GPL-3.0-1-ov-file)

script_name("rustlerFireFix")
script_author("d7.KrEoL")
script_version("1.0.0")
script_url("https://vk.com/d7kreol")
script_description("Gunshots fix for rustler")

local NEAREST_DISTANCE = 7.5 --Area for player to register splash. float:7.5 is closest to original imho
local BULLET_WAIT = 120 --Waiting after send BulletSync packet, not to flood server. LTD:AC#14 when less then 110
local RUSTLER_OFFSET = 4.5 --Offset from plane for player/vehicle collision check
local SYNC_TIMEOUT = 13 --Time between OnFoot sync, android clients do not register bulletsync without it. LTD kicks if value is 5 or less.

local isRustlerFire = true
local isRustlerFireRender = 0
local syncTime = os.clock()

function main()
	initVars()
	onUpdate()
end

function onUpdate()
	while true do
		if isRustlerFire then
			rustlerFindHit()
		end
		wait(0)
	end
end

function initVars()
	repeat wait(0) until isSampLoaded()
	repeat wait(0) until isSampAvailable()
	local result = sampRegisterChatCommand("rustlerFire", cmdRustlerFire)
	if not result then print("{FFFFFF}Error: cannot register chat command") end
	result = sampfuncsRegisterConsoleCommand("rustlerFire", cmdRustlerFire)
	if not result then 
		print("{FFFFFF}Error: cannot register console command 'rustlerFire'") 
	else
		print("{00FF00}rustlerFireFix - use console command 'rustlerFire' or chat command '/rustlerfire' to switch fix activity status")
	end
	result = sampfuncsRegisterConsoleCommand("rustlerFireRender", cmdRustlerFireRender)
	if not result then 
		print("{FFFFFF}Error: cannot register console command 'rustlerFireRender'") 
	else
		print("{00FF00}rustlerFireFix - use console command 'rustlerFire' or chat command '/rustlerfire' to switch fix activity status")
	end
end

function cmdRustlerFire()
	isRustlerFire = not isRustlerFire
	print("{FF00FF}rustlerFire:", (rustlerFire and "{00FF00}" or "{FF0000}"), isRustlerFire)
end

function cmdRustlerFireRender(arg)
	local value = tonumber(arg)
	if value == nil or value > 2 or value < 0 then 
		print("{FF0000}Error: cannot set rustlerFireRender value: ", value)
		print("Usage: rustlerFireRender [integer:0-2]")
		print("value '0' is not render;")
		print("value '1' is render only hits;")
		print("value '2' is render all;")
		return 
	end
	isRustlerFireRender = value
	print("{FF00FF}rustlerFireRender:", (isRustlerFireRender > 0 and "{00FF00}" or "{FF0000}"), isRustlerFireRender)
end

function rustlerFindHit()
	if (not isCharInAnyCar(PLAYER_PED)) then return end
	if (not isKeyDown(0xA2)) then return end
	
	
	local veh = {id = 0, pos = {x = 0, y = 0, z = 0}, vec = {x = 0, y = 0, z = 0}}
	veh.id =  storeCarCharIsInNoSave(PLAYER_PED)
	if getCarModel(veh.id) ~= 476 then return end
	
	veh.pos.x, veh.pos.y, veh.pos.z = getOffsetFromCarInWorldCoords(veh.id, 0, RUSTLER_OFFSET, 0)
	veh.vec.x, veh.vec.y, veh.vec.z = getOffsetFromCarInWorldCoords(veh.id, 0, 200, 0)
	
	local findType, object = findNearestCharOrCar(veh.vec, veh.pos)
	if findType == nil or findType == 0 then return end
	if findType == 1 then
		local pedX, pedY, pedZ = getCharCoordinates(object)
		local isOk, playerid = sampGetPlayerIdByCharHandle(object)
		if not isOk then return end
		if sampIsPlayerPaused(playerid) then return end
		
		-- local playerHealth = getCharHealth(object)--uncomment to see stats in console
		-- print("player id:", playerid, "hp:", playerHealth)--uncomment to see stats in console
		syncPlayer()
		giveDamagePed({targetid = playerid, pos = veh.pos, vec = {x = pedX, y = pedY, z = pedZ}, ped = {x = pedX, y = pedY, z = pedZ}})
		if isRustlerFireRender > 0 then
			renderCollisionPoint({x = pedX, y = pedY, z = pedZ})
		end
	elseif findType == 2 then
		local isOk, vehicleid = sampGetVehicleIdByCarHandle(object)
		
		if not isOk then return end
		if not (doesVehicleExist(object)) then return end
		
		local carX, carY, carZ = getCarCoordinates(object)

		local pid = getDriverOfCar(object)
		local isSampPid, sampPid = sampGetPlayerIdByCharHandle(pid)
		
		if not isSampPid then return end
		if not (sampIsPlayerConnected(sampPid)) then return end
		if sampIsPlayerPaused(sampPid) then return end
		
		-- local carhp = getCarHealth(object)--uncomment to see stats in console
		-- print("veh id: ", vehicleid, "hp:", carhp)--uncomment to see stats in console
		syncPlayer()
		giveDamageVeh({targetid = vehicleid, pos = veh.pos, vec = {x = pedX, y = pedY, z = pedZ}, ped = {x = carX, y = carY, z = carZ}, playerid = sampPid})
		if isRustlerFireRender > 0 then
			renderCollisionPoint({x = carX, y = carY, z = carZ})
		end
	end
end

function syncPlayer()
	if (os.clock() - syncTime < SYNC_TIMEOUT) then return end
	syncTime = os.clock()
	setCurrentCharWeapon(PLAYER_PED, 31)
	sampForceOnfootSync()
end

function findNearestCharOrCar(position, vehiclePosition)

	local object = 0
	local objectType = 0
	
	local result, colPoint = findColPoint(vehiclePosition, position, NEAREST_DISTANCE)
	
	if not result then return objectType, object end
	if colPoint.entityType == 3 then
		local charid = getCharPointerHandle(colPoint.entity)
		if charid ~= nil and doesCharExist(charid) and charid ~= PLAYER_PED then
			objectType = 1
			object = charid
			if isRustlerFireRender > 0 then
				renderCollisionPoint({x = colPoint.pos[1], y = colPoint.pos[2], z = colPoint.pos[3]})
			end
		end
	elseif colPoint.entityType == 2 then
		local vehicleHandle = getVehiclePointerHandle(colPoint.entity)
		if vehicleHandle ~= nil and doesVehicleExist(vehicleHandle) then
			local modelID = getCarModel(vehicleHandle)
			if  isThisModelAPlane(modelID) and isCarPassengerSeatFree(vehicleHandle, 1) then return objectType, object end
			objectType = 2
			object = vehicleHandle
			if isRustlerFireRender > 0 then
				renderCollisionPoint({x = colPoint.pos[1], y = colPoint.pos[2], z = colPoint.pos[3]})
			end
		end
	end
	return objectType, object
end

function findColPoint(startPosition, endPosition, size)
	local result, colPoint = processLineOfSight(
		startPosition.x, 
		startPosition.y, 
		startPosition.z, 
		endPosition.x, 
		endPosition.y, 
		endPosition.z, 
		false, 
		true, 
		true, 
		false, 
		false, 
		false, 
		false, 
		false)
	local plus = {x = -size, y = -size, z = -size}
	while not result and plus.z < size + 1 do 
		while not result and plus.x < size + 1 do
			result, colPoint = processLineOfSight(
				startPosition.x, 
				startPosition.y, 
				startPosition.z, 
				endPosition.x + plus.x, 
				endPosition.y + plus.y, 
				endPosition.z + plus.z, 
				false, 
				true, 
				true, 
				false, 
				false, 
				false, 
				false, 
				false)
			plus.x = plus.x + 1
			plus.y = plus.y + 1
			if isRustlerFireRender > 1 then
				local sX1, sY1 = convert3DCoordsToScreen(startPosition.x, startPosition.y, startPosition.z)
				local sX2, sY2 = convert3DCoordsToScreen(endPosition.x + plus.x, endPosition.y + plus.y, endPosition.z + plus.z)
				renderDrawLine(sX1, sY1, sX2, sY2, 1, 0xFFFF00FF)
			end
		end
		plus.x = -size
		plus.y = -size
		plus.z = plus.z + 1
	end
	return result, colPoint
end

function giveDamagePed(data)
	if not sampIsPlayerConnected(data.targetid) then return end
		
	local newData = {
			targetType = 1,
			targetId = data.targetid,
			origin = data.pos,
			target = data.vec,
			center = data.ped,
			weaponId = 31,
		}
	syncData = newData
	dmgData = {isTake = 0, targetid = newData.targetId, damage = 9.9000005722046, weapon = 31, bodyPart = 3}
	
	sendBulletSync(newData)
	sendDamageSync(dmgData)
end

function sendBulletSync(data)
	
	local bs = raknetNewBitStream()
	raknetBitStreamWriteInt8(bs, 206)
	raknetBitStreamWriteInt8(bs, data.targetType)
	raknetBitStreamWriteInt16(bs, data.targetId)
	raknetBitStreamWriteFloat(bs, data.origin.x)
	raknetBitStreamWriteFloat(bs, data.origin.y)
	raknetBitStreamWriteFloat(bs, data.origin.z)
	raknetBitStreamWriteFloat(bs, data.target.x)
	raknetBitStreamWriteFloat(bs, data.target.y)
	raknetBitStreamWriteFloat(bs, data.target.z)
	raknetBitStreamWriteFloat(bs, math.random(0, 0.5))--offset
	raknetBitStreamWriteFloat(bs, math.random(0, 0.5))
	raknetBitStreamWriteFloat(bs, math.random(0, 0.5))

	raknetBitStreamWriteInt8(bs, data.weaponId)
	raknetSendBitStream(bs)
	raknetDeleteBitStream(bs)
	wait(BULLET_WAIT)
end

function sendDamageSync(data)
		sampSendGiveDamage(data.isTake, data.targetid, data.damage, data.weapon, data.bodyPart)
end

function giveDamageVeh(data)--LTD:AC#14 sometimes
	
	local newData = {
		targetType = 2,
		targetId = data.targetid,
		origin = data.pos,
		target = data.vec,
		center = data.ped,
		weaponId = 31,
	}
	sendBulletSync(newData)
	
	if (not sampIsPlayerConnected(data.playerid)) then return end
end

function renderTriangle(screenX, screenY, size, color)
	renderBegin(3)
	renderColor(color)
	
	renderVertex(screenX - size, screenY - size)
	renderVertex(screenX, screenY + size)
	renderVertex(screenX + size, screenY - size)
	renderVertex(screenX - size, screenY - size)
	
	renderEnd()
end

function renderCollisionPoint(position)
	local screenX, screenY = convert3DCoordsToScreen(position.x, position.y, position.z)
	renderTriangle(screenX, screenY, 5, 0xFFFF00FF)
end
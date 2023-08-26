local isNearPump = false
local isFueling = false
local currentFuel = 0.0
local currentV
local fuelSynced = false
local lastAmount = 0
local nozzle
local rope
local disableMovements = false

if Config.framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

function ShowHelpNotification(msg)
    AddTextEntry('HelpNotification', msg)
    BeginTextCommandDisplayHelp('HelpNotification')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function ShowNotify(text)
    SetTextFont(fontId)
	SetNotificationTextEntry('STRING')
	AddTextComponentSubstringPlayerName(text)
	DrawNotification(false, true)
end

local function toggleNuiFrame(shouldShow)
    SetNuiFocus(shouldShow, shouldShow)
    SendReactMessage('setVisible', shouldShow)
end

function SendReactMessage(action, data)
    SendNUIMessage({
        action = action,
        data = data
    })
end

RegisterNUICallback('hideFrame', function(_, cb)
    toggleNuiFrame(false)
    cb({})
end)

RegisterNUICallback('LoadTranslations', function(_, cb)
    cb(Config.Strings)
end)

function FinishProgressBar()
    local ped = PlayerPedId()
    currentFuel = GetVehicleFuelLevel(currentV)
    if (currentFuel + lastAmount) > 100 then
        SetFuel(currentV, 100.0)
    else
        SetFuel(currentV, currentFuel + lastAmount)
    end
    SendReactMessage('stopSound')
    dropNozzle()
    ClearPedTasks(ped)
    RemoveAnimDict("timetable@gardener@filling_can")
    isFueling = false
    disableMovements = false
end

function CancelProgressBar()
    local ped = PlayerPedId()
    ShowNotify(Config.Strings.Cancel)
    ClearAllPedProps(ped)
    ClearPedTasks(ped)
    SendReactMessage('stopSound')
    isFueling = false
end

function StartProgressBar()
    if Config.framework == 'qbcore' then
        QBCore.Functions.Progressbar("fueling_vehicle", Config.Strings.Refueling, Config.ProgressTime * 1000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            FinishProgressBar()
        end, function()
            CancelProgressBar()
        end)
    elseif Config.framework == 'es_extended' then
        disableMovements = true
        if GetResourceState('esx_progressbar') == 'started' then
            exports["esx_progressbar"]:Progressbar(Config.Strings.Refueling, Config.ProgressTime * 1000,{
                FreezePlayer = false,
                animation ={},
                onFinish = function()
                    FinishProgressBar()
                end
            })
        else
            SetTimeout(Config.ProgressTime * 1000, function ()
                FinishProgressBar()
            end)
        end
    elseif Config.framework == 'custom' then
        disableMovements = true
        SetTimeout(Config.ProgressTime * 1000, function ()
            FinishProgressBar()
        end)
    end
end

function StartFueling()
    isFueling = true
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, currentV, 1000)
    Citizen.Wait(1000)
    grabNozzleFromPump()
    LoadAnimDict("timetable@gardener@filling_can")
    TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
    StartProgressBar()
end

RegisterNUICallback('checkMoney', function(data, cb)
    TriggerCallback('gacha_fuel:callback:hasMoney', function(result)
        if result then
            lastAmount = data
            toggleNuiFrame(false)
            StartFueling()
        else
            ShowNotify(Config.Strings.NoMoney)
        end
        cb(result)
    end, data)
end)

function LoadAnimDict(dict)
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)
		while not HasAnimDictLoaded(dict) do
			Wait(1)
		end
	end
end

function grabNozzleFromPump()
	local ped = PlayerPedId()
	local pumpObject, pumpDistance = FindNearestFuelPump()
	local pump = GetEntityCoords(pumpObject)
    LoadAnimDict("anim@am_hold_up@male")
    TaskPlayAnim(ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
    Wait(300)
    nozzle = CreateObject('prop_cs_fuel_nozle', 0, 0, 0, true, true, true)
    AttachEntityToEntity(nozzle, ped, GetPedBoneIndex(ped, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
    end
    RopeLoadTextures()
    while not pump do
        Wait(0)
    end
    rope = AddRope(pump.x, pump.y, pump.z, 0.0, 0.0, 0.0, 3.0, 1, 1000.0, 0.0, 1.0, false, false, false, 1.0, true)
    while not rope do
        Wait(0)
    end
    ActivatePhysics(rope)
    Wait(50)
    local nozzlePos = GetEntityCoords(nozzle)
    nozzlePos = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)
    AttachEntitiesToRope(rope, pumpObject, nozzle, pump.x, pump.y, pump.z + 1.45, nozzlePos.x, nozzlePos.y, nozzlePos.z, 5.0, false, false, nil, nil)
end

function dropNozzle()
    DetachEntity(nozzle, true, true)
	DeleteRope(rope)
	DeleteEntity(nozzle)
end

function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))

		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end

Citizen.CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)
	while true do
		Citizen.Wait(2000)

		local ped = PlayerPedId()

		if IsPedInAnyVehicle(ped) and GetEntityModel(GetVehiclePedIsIn(PlayerPedId())) ~= -1963629913 then
			local vehicle = GetVehiclePedIsIn(ped)

			if GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end
		end
	end
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 750
        if disableMovements then
            sleep = 0
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 36, true)
            DisableControlAction(0, 21, true)
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(1, 37, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
        end
        Wait(sleep)
    end
end)

Citizen.CreateThread(function()
	while true do
		local sleep = 750

		local pumpObject, pumpDistance = FindNearestFuelPump()

		if pumpDistance < 10 then
			sleep = 250
		end

		if pumpDistance < 2.5 then
			isNearPump = pumpObject
		else
			isNearPump = false

			Citizen.Wait(math.ceil(pumpDistance * 20))
		end
		Citizen.Wait(sleep)
	end
end)

Citizen.CreateThread(function()
	while true do
		local ped = PlayerPedId()
		if not isFueling and ((isNearPump and GetEntityHealth(isNearPump) > 0)) then
			if IsPedInAnyVehicle(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped), -1) == ped and GetEntityModel(GetVehiclePedIsIn(PlayerPedId())) ~= -1963629913 then
				ShowHelpNotification(Config.Strings.ExitVehicle)
			else
				local vehicle = GetPlayersLastVehicle()
				local vehicleCoords = GetEntityCoords(vehicle)

				if DoesEntityExist(vehicle) and #(GetEntityCoords(ped) - vehicleCoords) < 2.5 and GetEntityModel(vehicle) ~= -1963629913 then
					if not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
						local canFuel = true
						if GetVehicleFuelLevel(vehicle) < 95 and canFuel then
                            ShowHelpNotification(Config.Strings.EToRefuel)
                            if IsControlJustReleased(0, 38) then
                                currentV = vehicle
                                ClearPedTasks(PlayerPedId())
                                SendReactMessage('loadPriceLitre', Config.PriceLitre)
                                toggleNuiFrame(true)
                                SendReactMessage('loadActFuel', Round(GetFuel(vehicle), 0))
                            end
						else
							ShowHelpNotification(Config.Strings.FullTank)
						end
					end
				else
					Citizen.Wait(250)
				end
			end
		else
			Citizen.Wait(250)
		end

		Citizen.Wait(0)
	end
end)

if Config.ShowNearestGasStationOnly then
	Citizen.CreateThread(function()
		local currentGasBlip = 0

		while true do
			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords

			for _, gasStationCoords in pairs(Config.GasStations) do
				local dstcheck = #(coords - gasStationCoords)

				if dstcheck < closest then
					closest = dstcheck
					closestCoords = gasStationCoords
				end
			end

			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end

			currentGasBlip = CreateBlip(closestCoords)

			Citizen.Wait(10000)
		end
	end)
elseif Config.ShowAllGasStations then
	Citizen.CreateThread(function()
		for _, gasStationCoords in pairs(Config.GasStations) do
			CreateBlip(gasStationCoords)
		end
	end)
end

function GetFuel(vehicle)
	return DecorGetFloat(vehicle, Config.FuelDecor)
end

function SetFuel(vehicle, fuel)
	if type(fuel) == 'number' and fuel >= 0 and fuel <= 100 then
		SetVehicleFuelLevel(vehicle, fuel + 0.0)
		DecorSetFloat(vehicle, Config.FuelDecor, GetVehicleFuelLevel(vehicle))
	end
end

function LoadAnimDict(dict)
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)

		while not HasAnimDictLoaded(dict) do
			Citizen.Wait(1)
		end
	end
end

function Round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function CreateBlip(coords)
	local blip = AddBlipForCoord(coords)

	SetBlipSprite(blip, 361)
	SetBlipScale(blip, 0.9)
	SetBlipColour(blip, 4)
	SetBlipDisplay(blip, 4)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Gasolinera")
	EndTextCommandSetBlipName(blip)

	return blip
end

function FindNearestFuelPump()
	local coords = GetEntityCoords(PlayerPedId())
	local fuelPumps = {}
	local handle, object = FindFirstObject()
	local success

	repeat
		if Config.PumpModels[GetEntityModel(object)] then
			table.insert(fuelPumps, object)
		end

		success, object = FindNextObject(handle, object)
	until not success

	EndFindObject(handle)

	local pumpObject = 0
	local pumpDistance = 1000

	for _, fuelPumpObject in pairs(fuelPumps) do
		local dstcheck = #(coords - GetEntityCoords(fuelPumpObject))

		if dstcheck < pumpDistance then
			pumpDistance = dstcheck
			pumpObject = fuelPumpObject
		end
	end

	return pumpObject, pumpDistance
end
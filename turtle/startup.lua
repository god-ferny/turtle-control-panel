local connectionURL = "127.0.0.1:5757" --replace with your server IP

local ws, err = http.websocket(connectionURL)
if not ws then
    return printError(err)
end

print("> CONNECTED")

function ArrayToObject(arr)
    local result = {}
    
    for k, v in pairs(arr) do
        result[tostring(k)] = arr[k];
    end

    return result
end

function Eval(f, uuid)
    local func = loadstring(f)
    local result = {func()}
    local type = "EVAL"
    local response = { uuid = uuid, type = type, message = result }
    ws.send(textutils.serializeJSON(response))
end

--removed broken item identifier system as its completely broken, ill look into recoding it as well
function Handshake(uuid)
    local id = os.getComputerID()
    local label = os.getComputerLabel()
    local inventory = {}
    for i = 1, 16 do
        local item = turtle.getItemDetail(i, true)
        inventory[tostring(i)] = item
    end
    turtle.select(1)
    local fuelLevel = turtle.getFuelLevel()
    local fuelLimit = turtle.getFuelLimit()
    local fuel = { level = fuelLevel, limit = fuelLimit }
    local x, y, z = gps.locate()
    if (x == nil) then
        return ws.send(textutils.serializeJSON({ type = "ERROR", uuid = uuid, message = "nogps: Failed to connect to the GPS" }))
    end
-- removed stuck notifier because honestly kinda usless for now i plan on readding it later with a bit better logic

--extra debugging to the GPS since you cant differentiate them
    local x2, y2, z2 = gps.locate()
    if (x2 == nil) then
        return ws.send(textutils.serializeJSON({ type = "ERROR", uuid = uuid, message = "nogps: Failed to connect to the GPS X2" }))
    end

    local heading
    if movedBackwards then
        heading = vector.new(x, y, z) - vector.new(x2, y2, z2)
    else
        heading = vector.new(x2, y2, z2) - vector.new(x, y, z)
    end
    local direction = ((heading.x + math.abs(heading.x) * 2) + (heading.z + math.abs(heading.z) * 3))
    local location = { x = x2, y = y2, z = z2 }
    local selectedSlot = turtle.getSelectedSlot()
    local computer = { id = id, label = label, fuel = fuel, inventory = inventory, location = location, direction = direction, selectedSlot = selectedSlot }
    local response = { type = "HANDSHAKE", uuid = uuid, message = computer }
    ws.send(textutils.serializeJSON(response))
end

while true do
    local message = ws.receive()
    if message == nil then
        ws.close()
        print("> RECONNECTING...")
        ws, err = http.websocket(connectionURL)
        if not ws then
            return printError(err)
        end
        print("> CONNECTED")
    else
        local obj = textutils.unserializeJSON(message)
        if obj.type == "HANDSHAKE" then
            Handshake(obj.uuid)
        elseif obj.type == "RENAME" then
            os.setComputerLabel(obj["message"])
            local response = { type = "RENAME", uuid = obj.uuid }
            ws.send(textutils.serializeJSON(response))
        elseif obj.type == "EVAL" then
            Eval(obj["function"], obj.uuid)
        elseif obj.type == "DISCONNECT" then
            ws.close()
            return print("TERMINATED")
        elseif obj.type == "REBOOT" then
            ws.close()
            print("> REBOOTING")
            os.reboot()
        end
    end
end
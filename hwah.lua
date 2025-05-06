-- Luarmor Key Verification Library
-- This script handles key validation and script loading for protected content

-- Define main hashing function
local hashFunction

-- Placeholder for script ID that will be set later
local scriptId

-- Get HttpService for API communication
local HttpService = game:GetService("HttpService")

-- Function to decode JSON responses
local function decodeJson(jsonString)
    return HttpService:JSONDecode(jsonString)
end

-- Define the HTTP request function based on available methods
local httpRequest = syn and syn.request or request or http_request

-- Implementation of the custom hashing algorithm
do
    -- Helper function for modulo operation
    local function applyModulo(num)
        return num % 4294967296
    end
    
    -- Helper function for XOR operation
    local function xorOperation(a, b)
        local result, multiplier = 0, 1
        while a > 0 or b > 0 do
            local bitA = a % 2
            local bitB = b % 2
            if bitA ~= bitB then
                result = result + multiplier
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            multiplier = multiplier * 2
        end
        return result
    end
    
    -- Helper function for left shift operation
    local function leftShift(num, bits)
        return applyModulo(num * 2 ^ bits)
    end
    
    -- Helper function for right shift operation
    local function rightShift(num, bits)
        return math.floor(num / 2 ^ bits) % 4294967296
    end
    
    -- Main hashing function implementation
    function hashFunction(input)
        -- Initialize state values
        local state = {
            [1] = 1524013928,
            [2] = 62333482,
            [3] = 755453430,
            [4] = 3411017517
        }
        
        -- Constants used in the algorithm
        local constants = {
            [1] = 451,
            [2] = 41992,
            [3] = 38477,
            [4] = 17184
        }
        
        -- Process input in 4-byte chunks
        local length = #input
        local position = 1
        while position <= length do
            local chunk = 0
            for i = 0, 3 do
                local bytePos = position - 1 + i
                if bytePos < length then
                    local byte = input:byte(bytePos + 1)
                    chunk = chunk + byte * 2 ^ (8 * i)
                end
            end
            
            chunk = applyModulo(chunk)
            
            -- Transform state using chunk data
            for i = 1, 4 do
                local value = xorOperation(state[i], chunk)
                local nextState = state[i % 4 + 1]
                value = xorOperation(value, nextState)
                value = applyModulo(leftShift(value, 5) + rightShift(value, 2) + constants[i])
                local rotationAmount = (i - 1) * 5 % 32
                local rotatedChunk = rightShift(chunk, rotationAmount)
                value = xorOperation(value, rotatedChunk)
                value = applyModulo(value)
                local additionalState = state[(i + 1) % 4 + 1]
                value = applyModulo(value + additionalState)
                state[i] = applyModulo(value)
            end
            
            position = position + 4
        end
        
        -- Final transformation of state
        for i = 1, 4 do
            local value = state[i]
            local nextState = state[i % 4 + 1]
            local furtherState = state[(i + 2) % 4 + 1]
            value = applyModulo(value + nextState)
            value = xorOperation(value, furtherState)
            local rotationAmount = i * 7 % 32
            value = applyModulo(leftShift(value, rotationAmount) + rightShift(value, 32 - rotationAmount))
            state[i] = value
        end
        
        -- Convert state to hexadecimal string
        local result = {}
        for i = 1, 4 do
            result[i] = string.format("%08X", state[i])
        end
        
        return table.concat(result)
    end
end

-- Function to verify key with server
local function verifyKey(key)
    local currentTime = os.time()
    key = tostring(key)
    scriptId = tostring(scriptId)
    
    -- Get server info and nodes
    local serverInfo = httpRequest({
        Method = "GET",
        Url = "https://sdkapi-public.luarmor.net/sync"
    })
    serverInfo = decodeJson(serverInfo.Body)
    
    -- Select random node for load balancing
    local nodes = serverInfo.nodes
    local selectedNode = nodes[math.random(1, #nodes)]
    
    -- Build verification URL
    local verificationUrl = selectedNode .. "check_key?key=" .. key .. "&script_id=" .. scriptId
    
    -- Synchronize time with server
    local serverTime = serverInfo.st
    local timeDifference = serverTime - currentTime
    currentTime = currentTime + timeDifference
    
    -- Send verification request with hash
    local verificationResponse = httpRequest({
        Method = "GET",
        Url = verificationUrl,
        Headers = {
            ["clienttime"] = currentTime,
            ["catcat128"] = hashFunction(key .. "_cfver1.0_" .. scriptId .. "_time_" .. currentTime)
        }
    })
    
    return decodeJson(verificationResponse.Body)
end

-- Function for cache validation
local function validateCache()
    scriptId = tostring(scriptId)
    if not scriptId:match("^[a-f0-9]{32}$") then
        return
    end
    
    -- Create and delete cache file to check write permissions
    pcall(writefile, scriptId .. "-cache.lua", "recache is required")
    wait(0.1)
    pcall(delfile, scriptId .. "-cache.lua")
end

-- Function to load protected script
local function loadProtectedScript()
    loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/" .. tostring(scriptId) .. ".lua"))()
end

-- Return interface table with metatable
return setmetatable({}, {
    -- Handle property access to return specific functions based on hash values
    __index = function(_, key)
        local keyHash = hashFunction(key)
        
        -- Return different functions based on hash values
        if keyHash == "30F75B193B948B4E96514636365A85CBCC" then
            return verifyKey
        end
        if keyHash == "2BCEA36EB24E250BBAB188C73A74DF10" then
            return validateCache
        end
        if keyHash == "756624F56542822D214B1FE25E8798CC6" then
            return loadProtectedScript
        end
        return nil
    end,
    
    -- Handle property assignment to set script ID
    __newindex = function(_, propertyName, value)
        if propertyName == "script_id" then
            scriptId = value
        end
    end
})

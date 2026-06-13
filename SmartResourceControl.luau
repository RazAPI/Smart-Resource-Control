--[[ 
    Filename.: SmartResourceControl.luau
    Description.: Attempts to improve performance + save resources by tracking usage data patterns
    Author.: lucibedroque \\ RazAPIx64.dll32 \\ RazAPIx64 \\ RazAPI \\ Raz \\ Lucien

    TODO:
    {
        "prevent LogService detection by outputting in a protected GUI"
    }
]]

--// Micro-optimizations
local task_wait = task.wait
local task_spawn = task.spawn
local number_range_new = NumberRange.new
local table_insert = table.insert
local table_remove = table.remove
local os_clock = os.clock
--// Loading time
local ResourceControlLoadingTime = os_clock()

--// Short Dependencies
local RazAPI = {
    Threads = {},
    Connections = {},

    GetLength = function(Object)
        local Types = { ["table"] = { value = function()
            local Length = 0

            for i,v in Object do
                Length += 1
            end

            return Length
        end}, ["string"] = { value = function()
            return #Object
        end} }

        return Types[type(Object)].value()
    end,

    DataModel = game
}

local PrintConsole = function(Option, Message)
    local Options = {[1] = print, [2] = warn, [3] = error}
    if not Options[Option] then error("Invalid option") end
    return Options[Option](Message)
end

local user_settings = UserSettings -- (i know, this does nothing. im just using it for the casing)
--// Services
local Stats = RazAPI.DataModel:GetService("Stats")
local Workspace = RazAPI.DataModel:GetService("Workspace")
local UserInputService = RazAPI.DataModel:GetService("UserInputService")
--// Engine Dependency Check
local Success = pcall(function()
    user_settings().GameSettings.FramerateCap = user_settings().GameSettings.FramerateCap
end)

if not Success then
    PrintConsole(2, "[ Smart Resource Control ]: Script execution halted due to missing capabilities, Please try another executor.")
    return
end

RazAPI.WriteThread = function(ThreadName, Callback)
    RazAPI.Threads[ThreadName] = task_spawn(Callback) 
    return RazAPI.Threads[ThreadName]
end

RazAPI.SignConnection = function(ConnectionName, Connection, Callback)
    RazAPI.Connections[ConnectionName] = Connection:Connect(Callback)
    return RazAPI.Connections[ConnectionName]
end

RazAPI.GameSettings = user_settings().GameSettings
RazAPI.RenderingSettings = settings().Rendering

--// Window Track
local LastFocusLostTime = 0
local TotalTimeOutOfFocus = 0
local WindowActiveTracking = true

RazAPI.SignConnection("FocusTimeThread[1]", UserInputService.WindowFocused, function()
    if LastFocusLostTime > 0 then
        TotalTimeOutOfFocus += os_clock() - LastFocusLostTime
        LastFocusLostTime = 0
    end

    WindowActiveTracking = true
end)

RazAPI.SignConnection("FocusTimeThreadReleased[2]", UserInputService.WindowFocusReleased, function()
    WindowActiveTracking = false
    LastFocusLostTime = os_clock()
end)

--// keep in mind, this is for caching.
--// im using a weak table because i realized this can cause a memory leak because i never actually cleaned the instance itself
local InstancePropertyStore = setmetatable({}, { __mode = "k" })
local MaterialRelatedObjects = { ["Part"] = true, ["UnionOperation"] = true, ["MeshPart"] = true, ["CornerWedgePart"] = true, ["TrussPart"] = true }
local InstanceCache = { Material = {}, Decal = {}, NumLife = {}, Explosion = {} }

--// Safe static check to avoid runtime :GetDescendants() thread crashes on heavy games
local TotalInitialInstances = #RazAPI.DataModel:GetDescendants()
local BypassMassPurge = TotalInitialInstances > 50000

--// Main Table
local ResourceControlService = {
    MemoryHelper = {
        GetMemoryUsage = function()
            return Stats:GetTotalMemoryUsageMb()
        end,

        GetMemoryUsageFormatted = function()
            local Usage = Stats:GetTotalMemoryUsageMb()

            if Usage > 999 then
                Usage = Usage / 1000
                return tostring(Usage) .. "GB"
            else
                return tostring(Usage) .. "MB"
            end
        end
    },

    SmartFrameControlService = {
        GetFrameTime = function()
            return Stats.FrameTime
        end
    },

    SmartWindowControlService = {
        GetStatus = function()
            return WindowActiveTracking
        end,

        GetTimeOutOfFocus = function()
            return TotalTimeOutOfFocus
        end,

        GetCurrentAwayTime = function()
            if not WindowActiveTracking and LastFocusLostTime > 0 then
                return os_clock() - LastFocusLostTime
            end

            return 0
        end
    },

    ObjectControl = {
        DegradeObject = function(Object)
            if InstancePropertyStore[Object] or not Object:IsDescendantOf(game) then return end

            pcall(function()
                if MaterialRelatedObjects[Object.ClassName] then
                    InstancePropertyStore[Object] = {
                        Material = Object.Material,
                        Reflectance = Object.Reflectance
                    }
                    Object.Material = Enum.Material.Plastic
                    Object.Reflectance = 0
                elseif Object.ClassName == "Decal" then
                    InstancePropertyStore[Object] = { Transparency = Object.Transparency }
                    Object.Transparency = 1
                elseif Object:IsA("ParticleEmitter") or Object:IsA("Trail") then
                    local CurrentLifetime = Object.Lifetime
                    if typeof(CurrentLifetime) == "NumberRange" then
                        InstancePropertyStore[Object] = { Lifetime = CurrentLifetime }
                        Object.Lifetime = number_range_new(0)
                    end
                elseif Object.ClassName == "Explosion" then
                    InstancePropertyStore[Object] = {
                        BlastPressure = Object.BlastPressure,
                        BlastRadius = Object.BlastRadius
                    }
                    Object.BlastPressure = 1
                    Object.BlastRadius = 1
                end
            end)
        end,

        RestoreObject = function(Object)
            local Stored = InstancePropertyStore[Object]
            if not Stored then return end

            local RestoreSuccess = pcall(function()
                if MaterialRelatedObjects[Object.ClassName] then
                    Object.Material = Stored.Material
                    Object.Reflectance = Stored.Reflectance
                elseif Object.ClassName == "Decal" then
                    Object.Transparency = Stored.Transparency
                elseif Object:IsA("ParticleEmitter") or Object:IsA("Trail") then
                    Object.Lifetime = Stored.Lifetime
                elseif Object.ClassName == "Explosion" then
                    Object.BlastPressure = Stored.BlastPressure
                    Object.BlastRadius = Stored.BlastRadius
                end
            end)

            if RestoreSuccess then
                InstancePropertyStore[Object] = nil
            end
        end,

        DegradeAllBatched = function()
            local Count = 0

            for Index, Bucket in InstanceCache do
                for Object in Bucket do
                    if Object and Object:IsDescendantOf(game) then
                        ResourceControlService.ObjectControl.DegradeObject(Object)
                        Count += 1

                        if Count % 50 == 0 then
                            task_wait()
                        end
                    else
                        Bucket[Object] = nil
                    end
                end
            end
        end,

        RestoreAll = function()
            for Object in InstancePropertyStore do
                ResourceControlService.ObjectControl.RestoreObject(Object)
            end
        end,
        
        PurgeMassiveParts = function(TargetFolderOrArray, MaxMsPerFrame)
            if BypassMassPurge then 
                return 
            end

            local Budget = (MaxMsPerFrame or 12) / 1000 
            local StartTime = os_clock()
            local Targets = typeof(TargetFolderOrArray) == "Instance" and TargetFolderOrArray:GetDescendants() or TargetFolderOrArray

            for i = #Targets, 1, -1 do
                local Object = Targets[i]
                if Object and Object:IsA("BasePart") and not Object:IsA("Terrain") and not Object:IsDescendantOf(Workspace:FindFirstChildOfClass("Terrain")) then
                    Object:Destroy()
                end

                if os_clock() - StartTime >= Budget then
                    task_wait()
                    StartTime = os_clock()
                end
            end
        end
    }
}

ResourceControlService.SmartWindowControlService.GetResponseTime = function()
    local Total = TotalTimeOutOfFocus

    if not WindowActiveTracking and LastFocusLostTime > 0 then
        Total += os_clock() - LastFocusLostTime
    end

    return Total
end

getfenv().ResourceControlService = ResourceControlService

local StoredFPSCap = getfpscap and getfpscap() or 60.0
local StoredQualityLevel = RazAPI.RenderingSettings.QualityLevel

local Terrain = Workspace.Terrain

local TerrainValues = {
    WaterWaveSize = Terrain.WaterWaveSize,
    WaterWaveSpeed = Terrain.WaterWaveSpeed,
    WaterReflectance = Terrain.WaterReflectance,
    WaterTransparency = Terrain.WaterTransparency
}

local FPSRecoveryThreshold = 43.5
local QualityReduced = false

--// Render Track Module
local StoredGlobalShadows = RazAPI.DataModel.Lighting.GlobalShadows

local MemoryThresholdMB = 2000
local MemoryThrottleActive = false

local FPSHistory = {}

--// avoid throttling
local function GetAverageFPS(CurrentFPS)
    table_insert(FPSHistory, CurrentFPS)

    if #FPSHistory > 10 then
        table_remove(FPSHistory, 1)
    end

    local Sum = 0

    for Index = 1, #FPSHistory do
        Sum += FPSHistory[Index]
    end

    return Sum / #FPSHistory
end

local function GetCacheBucket(Object)
    if MaterialRelatedObjects[Object.ClassName] then
        return InstanceCache.Material
    elseif Object.ClassName == "Decal" then
        return InstanceCache.Decal
    elseif Object:IsA("ParticleEmitter") or Object:IsA("Trail") then
        return InstanceCache.NumLife
    elseif Object.ClassName == "Explosion" then
        return InstanceCache.Explosion
    end

    return nil
end

local function PurgeTexturesGlobally()
    for _, Object in Workspace:GetDescendants() do
        if Object:IsA("Decal") or Object:IsA("Texture") then
            pcall(function() Object.Texture = "" end)
        elseif Object:IsA("MeshPart") then
            pcall(function() Object.TextureID = "" end)
        end
    end
end

local ThrottledByWindow = false

local RTM = RazAPI.WriteThread("RTMService (Render Track Module Service)[3]", function()
    while task_wait(1) do
        local AwayTime = ResourceControlService.SmartWindowControlService.GetCurrentAwayTime()
        local FrameResponseTime = ResourceControlService.SmartFrameControlService.GetFrameTime()
        local MemoryUsage = ResourceControlService.MemoryHelper.GetMemoryUsage()
        
        local IsFocused = ResourceControlService.SmartWindowControlService.GetStatus()
        local AverageFPS = IsFocused and GetAverageFPS(1 / FrameResponseTime) or 60

        if IsFocused and AverageFPS <= 30 and not QualityReduced then
            RazAPI.RenderingSettings.QualityLevel = 1
            QualityReduced = true
        elseif IsFocused and AverageFPS >= FPSRecoveryThreshold and QualityReduced and not MemoryThrottleActive then
            RazAPI.RenderingSettings.QualityLevel = Enum.QualityLevel.Automatic
            QualityReduced = false
        end

        local ItemsThrottled = RazAPI.GetLength(InstancePropertyStore)

        if MemoryUsage >= MemoryThresholdMB and not MemoryThrottleActive then
            MemoryThrottleActive = true

            PrintConsole(2, `[ Smart Resource Control ]: Limiting resource usage ({math.floor(MemoryUsage)}MB)`)
            StoredQualityLevel = RazAPI.RenderingSettings.QualityLevel
            StoredGlobalShadows = RazAPI.DataModel.Lighting.GlobalShadows

            RazAPI.DataModel.Lighting.GlobalShadows = false
            RazAPI.RenderingSettings.MeshCacheSize = 1
            RazAPI.RenderingSettings.QualityLevel = 2
            RazAPI.GameSettings.FramerateCap = 60

            --// im scared
            pcall(function()
                settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto
                RenderSettings.EagerBulkExecution = false 
            end)

            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0

            ResourceControlService.ObjectControl.DegradeAllBatched()
            PurgeTexturesGlobally()
            PrintConsole(2, `[ Smart Resource Control ]: Removing textures due to too much memory being in use ({math.floor(MemoryUsage)}MB)`)
            
            if not BypassMassPurge then
                task_spawn(function()
                    ResourceControlService.ObjectControl.PurgeMassiveParts(Workspace, 12)
                end)
            else
                PrintConsole(2, `[ Smart Resource Control ]: Disabled purging module due to too many instances ({TotalInitialInstances})`)
            end
        elseif (MemoryUsage < (MemoryThresholdMB - 200) or ItemsThrottled == 0) and MemoryThrottleActive and IsFocused then
            MemoryThrottleActive = false

            RazAPI.RenderingSettings.QualityLevel = StoredQualityLevel or Enum.QualityLevel.Automatic
            RazAPI.DataModel.Lighting.GlobalShadows = StoredGlobalShadows
            RazAPI.GameSettings.FramerateCap = StoredFPSCap

            Terrain.WaterWaveSize = TerrainValues.WaterWaveSize
            Terrain.WaterWaveSpeed = TerrainValues.WaterWaveSpeed
            Terrain.WaterReflectance = TerrainValues.WaterReflectance
            Terrain.WaterTransparency = TerrainValues.WaterTransparency

            ResourceControlService.ObjectControl.RestoreAll()
        end

        if AwayTime > 3.5 and not IsFocused then
            if not ThrottledByWindow then
                ThrottledByWindow = true
                RazAPI.GameSettings.FramerateCap = 60
                RazAPI.DataModel.Lighting.GlobalShadows = false

                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 0
            end
        elseif IsFocused and ThrottledByWindow then
            ThrottledByWindow = false
            table.clear(FPSHistory)
            MemoryThrottleActive = false

            local TargetFPS = StoredFPSCap

            if TargetFPS <= 30 then
                TargetFPS = (getfpscap and getfpscap() > 30) and getfpscap() or 60
            end

            RazAPI.GameSettings.FramerateCap = TargetFPS
            RazAPI.DataModel.Lighting.GlobalShadows = StoredGlobalShadows

            Terrain.WaterWaveSize = TerrainValues.WaterWaveSize
            Terrain.WaterWaveSpeed = TerrainValues.WaterWaveSpeed
            Terrain.WaterReflectance = TerrainValues.WaterReflectance
            Terrain.WaterTransparency = TerrainValues.WaterTransparency
            
            ResourceControlService.ObjectControl.RestoreAll()
        end
    end
end)

for Index, Object in Workspace:GetDescendants() do
    local Bucket = GetCacheBucket(Object)

    if Bucket then
        Bucket[Object] = true
    end
end

--// Instance Track Module
local ITM = RazAPI.WriteThread("ITMService (Instance Track Module Service)[4]", function()
    RazAPI.SignConnection("LoosenObjectQuality", UserInputService.WindowFocusReleased, function()
        for Index, Bucket in InstanceCache do
            for Object in Bucket do
                if Object and Object:IsDescendantOf(game) then
                    ResourceControlService.ObjectControl.DegradeObject(Object)
                else
                    Bucket[Object] = nil
                end
            end
        end
    end)

    RazAPI.SignConnection("RestoreObjectQuality", UserInputService.WindowFocused, function()
        getfenv().ResourceControlService.ObjectControl.RestoreAll()
    end)

    local TargetContainer = Workspace 

    RazAPI.SignConnection("LoosenDescendantQuality", TargetContainer.DescendantAdded, function(Object)
        local Bucket = GetCacheBucket(Object)

        if Bucket then
            Bucket[Object] = true
        end

        if not ResourceControlService.SmartWindowControlService.GetStatus() then
            ResourceControlService.ObjectControl.DegradeObject(Object)
        end
    end)

    RazAPI.SignConnection("RestoreQuality", TargetContainer.DescendantRemoving, function(Object)
        local Bucket = GetCacheBucket(Object)

        if Bucket then
            Bucket[Object] = nil
        end

        InstancePropertyStore[Object] = nil
    end)
end)

PrintConsole(1, `[ Smart Resource Control ]: Current instances ingame -> {TotalInitialInstances}`)
PrintConsole(1, `[ Smart Resource Control ]: Amount of Resource Control Threads -> {RazAPI.GetLength(RazAPI.Threads)}`)
PrintConsole(1, `[ Smart Resource Control ]: Amount of Resource Control Connections -> {RazAPI.GetLength(RazAPI.Connections)}`)
PrintConsole(1, `[ Smart Resource Control ]: Render Track Module loaded -> {tostring(RTM):gsub("thread: 0x", "")}`)
PrintConsole(1, `[ Smart Resource Control ]: Instance Track Module loaded -> {tostring(ITM):gsub("thread: 0x", "")}`)
PrintConsole(1, `[ Smart Resource Control ]: Loaded all modules & scheduled tasks in {math.floor((os_clock() - ResourceControlLoadingTime) * 10000) / 10000}ms`)
PrintConsole(1, `[ Smart Resource Control ]: Game Memory usage: {tostring(ResourceControlService.MemoryHelper.GetMemoryUsageFormatted())}`)

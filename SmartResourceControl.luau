--[[ 
    Filename.: SmartResourceControl.luau
    Description.: Attempts to improve performance + save resources by tracking usage data patterns
    Author.: lucibedroque \\ RazAPIx64.dll32 \\ RazAPIx64 \\ RazAPI \\ Raz \\ Lucien

    TODO:
    {
        "prevent LogService detection by outputting in a protected GUI": DONE
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

local user_settings = UserSettings -- (i know, this does nothing. im just using it for the casing)
--// Services
local Stats = RazAPI.DataModel:GetService("Stats")
local Workspace = RazAPI.DataModel:GetService("Workspace")
local UserInputService = RazAPI.DataModel:GetService("UserInputService")
--// Long
local CoreGui = gethui and gethui() or cloneref and cloneref(RazAPI.DataModel:GetService("CoreGui")) or RazAPI.DataModel:GetService("CoreGui")
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
--// console Stuff
local font_new = Font.new
local instance_new = Instance.new
local color3_fromrgb = Color3.fromRGB
local udim2_new = UDim2.new
local udim_new = UDim.new

local NewElement = function(ClassName, Properties)
    local Object = instance_new(ClassName)
    for Property, Value in Properties do Object[Property] = Value end
    return Object
end


local ConsoleGui = NewElement("ScreenGui", {
    Name = "SmartResourceControlConsole",
    ResetOnSpawn = false
})

local MainFrame = NewElement("Frame", {
    Size = udim2_new(0, 700, 0, 300),
    Position = udim2_new(0.5, -350, 0.5, -150),
    BackgroundColor3 = color3_fromrgb(12, 12, 16),
    BackgroundTransparency = 0.09,
    BorderSizePixel = 0,
    Active = false
})

local MainCorner = NewElement("UICorner", {
    CornerRadius = udim_new(0, 13)
})

local MainStroke = NewElement("UIStroke", {
    Color = color3_fromrgb(55, 55, 65),
    Thickness = 1,
    Transparency = 0.45
})

local TopBar = NewElement("Frame", {
    Size = udim2_new(1, 0, 0, 36),
    BackgroundColor3 = color3_fromrgb(20, 20, 25),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Active = false
})

local TopCorner = NewElement("UICorner", {
    CornerRadius = udim_new(0, 13)
})

local TopFill = NewElement("Frame", {
    Size = udim2_new(1, 0, 0, 13),
    Position = udim2_new(0, 0, 1, -13),
    BackgroundColor3 = color3_fromrgb(20, 20, 25),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0
})

local TitleLabel = NewElement("TextLabel", {
    Size = udim2_new(1, -50, 1, 0),
    Position = udim2_new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Smart Resource Control",
    TextColor3 = color3_fromrgb(245, 245, 245),
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    FontFace = font_new("rbxassetid://16658246179", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
})

local CloseButton = NewElement("TextButton", {
    Size = udim2_new(0, 10, 0, 10),
    Position = udim2_new(1, -24, 0, 11),
    BackgroundColor3 = color3_fromrgb(255, 95, 86),
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = true,
    Active = false
})

local CloseCorner = NewElement("UICorner", {
    CornerRadius = udim_new(1, 0)
})

local LogContainer = NewElement("ScrollingFrame", {
    Size = udim2_new(1, -12, 1, -48),
    Position = udim2_new(0, 6, 0, 42),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = udim2_new()
})

local LogLayout = NewElement("UIListLayout", {
    Padding = udim_new(0, 3),
    SortOrder = Enum.SortOrder.LayoutOrder
})

local LogPadding = NewElement("UIPadding", {
    PaddingLeft = udim_new(0, 8),
    PaddingRight = udim_new(0, 8),
    PaddingTop = udim_new(0, 8),
    PaddingBottom = udim_new(0, 8)
})

ConsoleGui.Parent = CoreGui
MainFrame.Parent = ConsoleGui
MainCorner.Parent = MainFrame
MainStroke.Parent = MainFrame
TopBar.Parent = MainFrame
TopCorner.Parent = TopBar
TopFill.Parent = TopBar
TitleLabel.Parent = TopBar
CloseButton.Parent = TopBar
CloseCorner.Parent = CloseButton
LogContainer.Parent = MainFrame
LogLayout.Parent = LogContainer
LogPadding.Parent = LogContainer

RazAPI.SignConnection("CloseConsole", CloseButton.MouseButton1Click, function()
    ConsoleGui:Destroy()
end)

--// Money can't buy happiness i think im happy with it

RazAPI.SignConnection("LogLayout", LogLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    LogContainer.CanvasSize = udim2_new(0, 0, 0, LogLayout.AbsoluteContentSize.Y + 16)
end)

local Dragging = false
local DragStart = nil
local StartPosition = nil
local LogMessages = {}

local PrintConsole = function(LogType, Message)
    local Text

    if LogType == 1 then
        Text = `<font color="#8AE7FF">[ {os.date("%H:%M:%S")} ] [ INFO ]</font> {Message}`
    elseif LogType == 2 then
        Text = `<font color="#FFD75E">[ {os.date("%H:%M:%S")} ] [ WARN ]</font> {Message}`
    elseif LogType == 3 then
        Text = `<font color="#FF6B6B">[ {os.date("%H:%M:%S")} ] [ ERROR ]</font> {Message}`
    else
        Text = tostring(Message)
    end

    local Label = NewElement("TextLabel", {
        Size = udim2_new(1, -4, 0, 18),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
        RichText = true,
        Text = Text,
        TextColor3 = color3_fromrgb(235, 235, 235),
        FontFace = font_new("rbxassetid://16658246179", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
        Parent = LogContainer
    })

    table_insert(LogMessages, Label)

    if #LogMessages > 250 then
        LogMessages[1]:Destroy()
        table_remove(LogMessages, 1)
    end
end

RazAPI.SignConnection("ConsoleDragStart", TopBar.InputBegan, function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    Dragging = true
    DragStart = Input.Position
    StartPosition = MainFrame.Position
end)

RazAPI.SignConnection("ConsoleDragEnd", UserInputService.InputEnded, function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = false
    end
end)

RazAPI.SignConnection("ConsoleDragUpdate", UserInputService.InputChanged, function(Input)
    if not Dragging or Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

    local Delta = Input.Position - DragStart

    MainFrame.Position = udim2_new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
end)

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

--// Safe static check to avoid :GetDescendants() crashing you on heavy games
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

--// Statistics Interface
local instance_new = Instance.new
local color3_fromrgb = Color3.fromRGB
local udim2_offset = UDim2.fromOffset
local udim2_new = UDim2.new
local udim_new = UDim.new
local font_new = Font.new

local ScreenGui = NewElement("ScreenGui", {
    Name = "SmartResourceControlStatistics",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})

local ExtraFrame = NewElement("Frame", {
    Size = udim2_offset(760, 32),
    Position = udim2_new(0, 1150, 0, -48),
    BackgroundColor3 = color3_fromrgb(20, 20, 20),
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Active = true
})

local UICorner = NewElement("UICorner", {
    CornerRadius = udim_new(0, 6)
})

local StatsLabel = NewElement("TextLabel", {
    Size = udim2_new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    FontFace = font_new("rbxassetid://16658246179", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
    TextSize = 13,
    TextColor3 = color3_fromrgb(255, 255, 255),
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    Text = "Loading...",
    Active = true,
    TextTruncate = Enum.TextTruncate.AtEnd
})

local UIPadding = NewElement("UIPadding", {
    PaddingLeft = udim_new(0, 12),
    PaddingRight = udim_new(0, 12)
})

local Dragging = false
local DragStart = nil
local StartPosition = nil
local LastStatsText = ""

ScreenGui.Parent = CoreGui
ExtraFrame.Parent = ScreenGui
UICorner.Parent = ExtraFrame
StatsLabel.Parent = ExtraFrame
UIPadding.Parent = StatsLabel

RazAPI.SignConnection("StatisticsDragStart", ExtraFrame.InputBegan, function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    Dragging = true
    DragStart = Input.Position
    StartPosition = ExtraFrame.Position
end)

RazAPI.SignConnection("StatisticsDragEnd", UserInputService.InputEnded, function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
end)

RazAPI.SignConnection("StatisticsDragUpdate", UserInputService.InputChanged, function(Input)
    if not Dragging or Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local Delta = Input.Position - DragStart
    ExtraFrame.Position = udim2_new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
end)

local UIHidden = false

RazAPI.SignConnection("KeybindModule", UserInputService.InputBegan, function(Input, Processed)
    if Processed then return end

    --// rather used if the user finds the UI annoying. you can use End instead to hide the UI and bring it back.
    local AltDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)

    if AltDown and Input.KeyCode == Enum.KeyCode.F then
        ScreenGui:Destroy()
        ConsoleGui:Destroy()

        return
    end

    if Input.KeyCode == Enum.KeyCode.End then
        UIHidden = not UIHidden

        ScreenGui.Enabled = not UIHidden
        ConsoleGui.Enabled = not UIHidden
    end
end)
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
    for unused, Object in Workspace:GetDescendants() do
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
        local ItemsThrottled = RazAPI.GetLength(InstancePropertyStore)

        local StatsText = `MEM {math.floor(MemoryUsage)}MB | FPS {math.floor(AverageFPS)} | FOCUS {IsFocused} | AWAY {math.floor(AwayTime)}s | MEMTHROTTLE {MemoryThrottleActive} | WINTHROTTLE {ThrottledByWindow} | DEGRADED {ItemsThrottled}`

        if StatsText ~= LastStatsText then
            LastStatsText = StatsText
            StatsLabel.Text = StatsText
        end

        if IsFocused and AverageFPS <= 30 and not QualityReduced then
            RazAPI.RenderingSettings.QualityLevel = 1
            QualityReduced = true
        elseif IsFocused and AverageFPS >= FPSRecoveryThreshold and QualityReduced and not MemoryThrottleActive then
            RazAPI.RenderingSettings.QualityLevel = Enum.QualityLevel.Automatic
            QualityReduced = false
        end

        if MemoryUsage >= MemoryThresholdMB and not MemoryThrottleActive then
            MemoryThrottleActive = true

            PrintConsole(2, `Limiting resource usage ({math.floor(MemoryUsage)}MB)`)
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
            PrintConsole(2, `Removing textures due to too much memory being in use ({math.floor(MemoryUsage)}MB)`)
            
            if not BypassMassPurge then
                task_spawn(function()
                    ResourceControlService.ObjectControl.PurgeMassiveParts(Workspace, 12)
                end)
            else
                PrintConsole(2, `Disabled purging module due to too many instances ({TotalInitialInstances})`)
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

PrintConsole(1, `Current instances ingame -> {TotalInitialInstances}`)
PrintConsole(1, `Amount of Resource Control Threads -> {RazAPI.GetLength(RazAPI.Threads)}`)
PrintConsole(1, `Amount of Resource Control Connections -> {RazAPI.GetLength(RazAPI.Connections)}`)
PrintConsole(1, `Render Track Module loaded -> {tostring(RTM):gsub("thread: 0x", "")}`)
PrintConsole(1, `Instance Track Module loaded -> {tostring(ITM):gsub("thread: 0x", "")}`)
PrintConsole(1, `Loaded all modules & scheduled tasks in {math.floor((os_clock() - ResourceControlLoadingTime) * 10000) / 10000}ms`)
PrintConsole(1, `Game Memory usage: {tostring(ResourceControlService.MemoryHelper.GetMemoryUsageFormatted())}`)

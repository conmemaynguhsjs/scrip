--========================================================--
-- KHANG NGUYEN DRAGON DEV PANEL v9
-- Security Test / Attacker Simulator | Roblox Studio
-- Place as a LocalScript in StarterPlayer > StarterPlayerScripts
--========================================================--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Local-only security simulation. No server permission bridge is required.
local StudioAuthorized = RunService:IsStudio()

--========================================================--
-- CONFIG
--========================================================--

local Config = {
    -- Upload the Kenzo image to Roblox and put its asset id here.
    BackgroundImage = "rbxassetid://0",
    BackgroundImageTransparency = 0.10,

    Speed = 100,
    FlySpeed = 300,
    ESPDistance = 500,
    HitboxSize = 100,

    SpeedEnabled = false,
    FlyEnabled = false,

    PlayerESP = false,
    EggESP = false,
    ShowNames = true,
    ShowDistance = true,

    LowGraphics = false,
    Particles = false,
    Shadows = false,

    Notifications = true,

    EggFilters = {
        Secret = true,
        Big = false,
        Mutation = false,
        Parasite = false,
        Monster = false,
        Event = false
    }
}

local Theme = {
    Background = Color3.fromRGB(6, 7, 10),
    Panel = Color3.fromRGB(12, 13, 18),
    Panel2 = Color3.fromRGB(19, 20, 27),
    Panel3 = Color3.fromRGB(27, 28, 37),
    Red = Color3.fromRGB(235, 45, 58),
    DarkRed = Color3.fromRGB(92, 12, 20),
    DragonGold = Color3.fromRGB(218, 164, 64),
    DragonDark = Color3.fromRGB(55, 37, 18),
    Text = Color3.fromRGB(248, 248, 250),
    SubText = Color3.fromRGB(164, 166, 176),
    Stroke = Color3.fromRGB(57, 59, 70)
}

local Connections = {}
local ESPObjects = {}
local OriginalLighting = {}

--========================================================--
-- HELPERS
--========================================================--

local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

local function New(className, props, parent)
    local obj = Instance.new(className)

    for k, v in pairs(props or {}) do
        obj[k] = v
    end

    obj.Parent = parent
    return obj
end

local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function Outline(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function Tween(obj, props, duration)
    TweenService:Create(
        obj,
        TweenInfo.new(duration or .18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function Notify(title, message)
    if not Config.Notifications then return end

    local holder = Interface.NotificationHolder

    local card = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 62)
    }, holder)

    Corner(card, 8)
    Outline(card, Theme.Red, 1)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Theme.Red,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left
    }, card)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 26),
        Size = UDim2.new(1, -24, 0, 30),
        Font = Enum.Font.Gotham,
        Text = message,
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left
    }, card)

    task.delay(3, function()
        if card.Parent then
            Tween(card, {BackgroundTransparency = 1}, .2)
            task.wait(.25)
            card:Destroy()
        end
    end)
end

--========================================================--
-- GUI
--========================================================--

local Gui = New("ScreenGui", {
    Name = "KhangNguyenDragonPanelV7",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, PlayerGui)

--========================================================--
-- KENZO STYLE MENU
-- The layout follows the supplied reference:
-- translucent purple glass panel + left navigation + image background.
--========================================================--

local Main = New("Frame", {
    Name = "Main",
    BackgroundColor3 = Color3.fromRGB(74, 58, 105),
    BackgroundTransparency = 0.16,
    Size = UDim2.new(0, 560, 0, 400),
    Position = UDim2.new(.5, -280, .5, -200),
    ClipsDescendants = true
}, Gui)

Corner(Main, 16)
Outline(Main, Color3.fromRGB(125, 103, 170), 1.2)

local KenzoBackground = New("ImageLabel", {
    Name = "KenzoBackground",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    Image = Config.BackgroundImage,
    ImageTransparency = Config.BackgroundImageTransparency,
    ScaleType = Enum.ScaleType.Crop,
    Active = false,
    ZIndex = 0
}, Main)

Corner(KenzoBackground, 16)

local BackgroundShade = New("Frame", {
    Name = "BackgroundShade",
    BackgroundColor3 = Color3.fromRGB(45, 28, 73),
    BackgroundTransparency = 0.36,
    Size = UDim2.new(1, 0, 1, 0),
    Active = false,
    ZIndex = 1
}, Main)

Corner(BackgroundShade, 16)

local MainGradient = New("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 39, 83)),
        ColorSequenceKeypoint.new(.5, Color3.fromRGB(90, 69, 125)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 36, 76))
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.30),
        NumberSequenceKeypoint.new(.5, 0.48),
        NumberSequenceKeypoint.new(1, 0.30)
    }),
    Rotation = 25
}, Main)

local Top = New("Frame", {
    Name = "Top",
    BackgroundColor3 = Color3.fromRGB(32, 25, 51),
    BackgroundTransparency = 0.34,
    Size = UDim2.new(1, 0, 0, 58),
    ZIndex = 3
}, Main)

Corner(Top, 16)

New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 0, 8),
    Size = UDim2.new(1, -145, 0, 22),
    Font = Enum.Font.GothamBold,
    Text = "FOXNAME - STEAL AN EGG",
    TextColor3 = Color3.fromRGB(245, 239, 255),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4
}, Top)

New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 15, 0, 31),
    Size = UDim2.new(1, -155, 0, 16),
    Font = Enum.Font.Gotham,
    Text = "KENZO PANEL  •  KEYLESS  •  v7",
    TextColor3 = Color3.fromRGB(191, 174, 225),
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4
}, Top)

local Keyless = New("TextLabel", {
    BackgroundColor3 = Color3.fromRGB(44, 125, 235),
    BackgroundTransparency = 0.05,
    Position = UDim2.new(1, -105, 0, 16),
    Size = UDim2.new(0, 65, 0, 25),
    Font = Enum.Font.GothamBold,
    Text = "Keyless",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 10,
    ZIndex = 4
}, Top)
Corner(Keyless, 7)

local Close = New("TextButton", {
    BackgroundColor3 = Color3.fromRGB(32, 24, 47),
    BackgroundTransparency = 0.25,
    Position = UDim2.new(1, -34, 0, 16),
    Size = UDim2.new(0, 25, 0, 25),
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(235, 225, 250),
    TextSize = 17,
    AutoButtonColor = false,
    ZIndex = 4
}, Top)

Corner(Close, 7)
Outline(Close, Color3.fromRGB(150, 130, 185), 1)

local Sidebar = New("ScrollingFrame", {
    Name = "Sidebar",
    BackgroundColor3 = Color3.fromRGB(28, 22, 44),
    BackgroundTransparency = 0.42,
    Position = UDim2.new(0, 8, 0, 66),
    Size = UDim2.new(0, 126, 1, -74),
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Color3.fromRGB(150, 119, 205),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 3
}, Main)

Corner(Sidebar, 10)
Outline(Sidebar, Color3.fromRGB(120, 98, 160), 1)

New("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, Sidebar)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, Sidebar)

local TabArea = New("Frame", {
    Name = "TabArea",
    BackgroundColor3 = Color3.fromRGB(33, 25, 52),
    BackgroundTransparency = 0.40,
    Position = UDim2.new(0, 142, 0, 66),
    Size = UDim2.new(1, -150, 1, -74),
    ClipsDescendants = true,
    ZIndex = 3
}, Main)

Corner(TabArea, 10)
Outline(TabArea, Color3.fromRGB(120, 98, 160), 1)

local NotificationHolder = New("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 8, 0, 78),
    Size = UDim2.new(1, -16, 0, 220),
    ZIndex = 50
}, Gui)

New("UIListLayout", {
    Padding = UDim.new(0, 7),
    VerticalAlignment = Enum.VerticalAlignment.Top
}, NotificationHolder)

local Interface = {
    NotificationHolder = NotificationHolder
}

--========================================================--
-- TAB SYSTEM
--========================================================--

local Tabs = {}

local function MakeTab(name, icon)
    local tabButton = New("TextButton", {
        BackgroundColor3 = Color3.fromRGB(49, 39, 70),
        BackgroundTransparency = 0.22,
        Size = UDim2.new(1, 0, 0, 34),
        Font = Enum.Font.GothamSemibold,
        Text = "  " .. icon .. "   " .. name,
        TextColor3 = Color3.fromRGB(204, 194, 222),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false
    }, Sidebar)

    Corner(tabButton, 8)
    Outline(tabButton, Theme.Stroke, 1)

    local page = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Red,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false
    }, TabArea)

    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)

    New("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 8)
    }, page)

    local function Select()
        for _, t in pairs(Tabs) do
            t.Page.Visible = false
            t.Button.BackgroundColor3 = Theme.Panel
            t.Button.TextColor3 = Theme.SubText
            local stroke = t.Button:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = Theme.Stroke end
        end

        page.Visible = true
        tabButton.BackgroundColor3 = Theme.DarkRed
        tabButton.TextColor3 = Theme.Text
        local stroke = tabButton:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = Theme.DragonGold end
    end

    Connect(tabButton.MouseButton1Click, Select)

    Tabs[name] = {
        Button = tabButton,
        Page = page,
        Select = Select
    }

    return page
end

local function Section(parent, title)
    local frame = New("Frame", {
        BackgroundColor3 = Color3.fromRGB(53, 42, 75),
        BackgroundTransparency = 0.18,
        Size = UDim2.new(1, 0, 0, 36)
    }, parent)

    Corner(frame, 7)

    local accent = New("Frame", {
        BackgroundColor3 = Theme.DragonGold,
        Position = UDim2.new(0, 0, 0, 7),
        Size = UDim2.new(0, 3, 0, 22)
    }, frame)
    Corner(accent, 2)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Theme.Red,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)
end

local function Button(parent, title, callback)
    local b = New("TextButton", {
        BackgroundColor3 = Color3.fromRGB(56, 44, 79),
        BackgroundTransparency = 0.16,
        Size = UDim2.new(1, 0, 0, 42),
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 12,
        AutoButtonColor = false
    }, parent)

    Corner(b, 7)
    Outline(b, Theme.Stroke, 1)

    Connect(b.MouseEnter, function()
        Tween(b, {BackgroundColor3 = Theme.DarkRed}, .1)
    end)

    Connect(b.MouseLeave, function()
        Tween(b, {BackgroundColor3 = Theme.Panel2}, .1)
    end)

    Connect(b.MouseButton1Click, callback)
    Connect(b.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            Tween(b, {BackgroundColor3 = Theme.DarkRed}, .08)
        end
    end)

    return b
end

local function Toggle(parent, title, default, callback)
    local value = default

    local frame = New("Frame", {
        BackgroundColor3 = Color3.fromRGB(48, 37, 69),
        BackgroundTransparency = 0.18,
        Size = UDim2.new(1, 0, 0, 44)
    }, parent)

    Corner(frame, 7)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        Font = Enum.Font.Gotham,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)

    local switch = New("TextButton", {
        BackgroundColor3 = Theme.DarkRed,
        Position = UDim2.new(1, -56, .5, -11),
        Size = UDim2.new(0, 44, 0, 22),
        Text = "",
        AutoButtonColor = false
    }, frame)

    Corner(switch, 11)

    local knob = New("Frame", {
        BackgroundColor3 = Theme.Text,
        Position = UDim2.new(0, 3, .5, -8),
        Size = UDim2.new(0, 16, 0, 16)
    }, switch)

    Corner(knob, 10)

    local function update()
        if value then
            switch.BackgroundColor3 = Theme.Red
            Tween(knob, {Position = UDim2.new(1, -19, .5, -8)}, .12)
        else
            switch.BackgroundColor3 = Theme.DarkRed
            Tween(knob, {Position = UDim2.new(0, 3, .5, -8)}, .12)
        end

        if callback then callback(value) end
    end

    Connect(switch.MouseButton1Click, function()
        value = not value
        update()
    end)

    update()

    return {
        Get = function() return value end,
        Set = function(v)
            value = v
            update()
        end
    }
end

local function Slider(parent, title, min, max, default, callback)
    local value = default

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 61)
    }, parent)

    Corner(frame, 7)

    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.Gotham,
        Text = title .. ": " .. default,
        TextColor3 = Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)

    local bar = New("Frame", {
        BackgroundColor3 = Theme.Panel2,
        Position = UDim2.new(0, 12, 0, 37),
        Size = UDim2.new(1, -24, 0, 7)
    }, frame)

    Corner(bar, 5)

    local fill = New("Frame", {
        BackgroundColor3 = Theme.Red,
        Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    }, bar)

    Corner(fill, 5)

    local dragging = false

    local function update(x)
        local percent = math.clamp(
            (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X,
            0, 1
        )

        value = math.floor(min + (max-min) * percent)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        label.Text = title .. ": " .. value

        if callback then callback(value) end
    end

    Connect(bar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)

    Connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            update(input.Position.X)
        end
    end)

    Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function TextBox(parent, title, placeholder, callback)
    local frame = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 57)
    }, parent)

    Corner(frame, 7)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 5),
        Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.Gotham,
        Text = title,
        TextColor3 = Theme.SubText,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)

    local box = New("TextBox", {
        BackgroundColor3 = Theme.Panel2,
        Position = UDim2.new(0, 10, 0, 27),
        Size = UDim2.new(1, -20, 0, 23),
        Font = Enum.Font.Gotham,
        Text = "",
        PlaceholderText = placeholder,
        TextColor3 = Theme.Text,
        TextSize = 11,
        ClearTextOnFocus = false
    }, frame)

    Corner(box, 5)

    Connect(box.FocusLost, function()
        if callback then callback(box.Text) end
    end)

    return box
end

--========================================================--
-- TABS
--========================================================--

local MainTab = MakeTab("Main", "◆")
local MovementTab = MakeTab("Movement", "➤")
local EggTab = MakeTab("Lấy Trứng", "◇")
local ESPTab = MakeTab("ESP", "◎")
local CombatTab = MakeTab("Combat", "⚔")
local FPSTab = MakeTab("FPS Boost", "⚡")
local ServerTab = MakeTab("Server", "▣")
local SettingsTab = MakeTab("Settings", "⚙")

--========================================================--
-- MAIN
--========================================================--

Section(MainTab, "SYSTEM")

local DragonBanner = New("Frame", {
    BackgroundColor3 = Theme.Panel2,
    Size = UDim2.new(1, 0, 0, 70)
}, MainTab)
Corner(DragonBanner, 9)
Outline(DragonBanner, Theme.DragonDark, 1)

New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 7),
    Size = UDim2.new(0, 42, 0, 42),
    Font = Enum.Font.GothamBlack,
    Text = "🐲",
    TextSize = 29,
    TextColor3 = Theme.DragonGold
}, DragonBanner)

New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 58, 0, 7),
    Size = UDim2.new(1, -70, 0, 22),
    Font = Enum.Font.GothamBold,
    Text = "DRAGON CORE",
    TextColor3 = Theme.DragonGold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left
}, DragonBanner)

New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 58, 0, 30),
    Size = UDim2.new(1, -70, 0, 28),
    Font = Enum.Font.Gotham,
    Text = "SECURITY TEST / ATTACKER SIMULATOR • local-only",
    TextColor3 = Theme.SubText,
    TextSize = 9,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left
}, DragonBanner)

local status = New("TextLabel", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 55),
    Font = Enum.Font.GothamBold,
    Text = "● READY  |  Developer Test Mode",
    TextColor3 = Theme.Red,
    TextSize = 13
}, MainTab)

Corner(status, 7)

Button(MainTab, "Refresh System Status", function()
    status.Text = "● READY  | Players: " .. #Players:GetPlayers()
    Notify("System", "Status refreshed.")
end)

Button(MainTab, "Scan Workspace", function()
    local count = #Workspace:GetDescendants()
    status.Text = "● Workspace objects: " .. count
    Notify("Workspace", "Đã quét " .. count .. " objects.")
end)

Button(MainTab, "Reset Local Character", function()
    local hum = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.Health = hum.MaxHealth
    end

    Notify("Character", "Character test reset.")
end)

--========================================================--
-- MOVEMENT
--========================================================--

Section(MovementTab, "MOVEMENT")

Toggle(MovementTab, "Speed Test", false, function(v)
    Config.SpeedEnabled = v

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.WalkSpeed = v and Config.Speed or 16
    end


    Notify("Movement", v and ("WalkSpeed ON: " .. Config.Speed) or "WalkSpeed OFF")
end)

Slider(MovementTab, "WalkSpeed", 8, 300, 100, function(v)
    Config.Speed = v

    if Config.SpeedEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = v
        end

    end
end)

--========================================================--
-- FLY CONTROLLER
-- Reference style: Attachment + LinearVelocity + AlignOrientation.
-- Uses camera-relative WASD and also supports the mobile joystick.
--========================================================--

local FlyEnabledLocal = false
local FlyMaxHeight = 2000
local FlyVerticalSpeed = 55
local FlyCurrentVelocity = Vector3.zero
local FlyAcceleration = 7

local FlyBodyVelocity = nil
local FlyAttachment = nil

local function GetFlyParts()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return char, root, hum
end

local function StopFly()
    FlyEnabledLocal = false
    Config.FlyEnabled = false
    FlyCurrentVelocity = Vector3.zero

    if FlyBodyVelocity then
        FlyBodyVelocity:Destroy()
        FlyBodyVelocity = nil
    end
    if FlyAttachment then
        FlyAttachment:Destroy()
        FlyAttachment = nil
    end

    local _, _, hum = GetFlyParts()
    if hum then
        hum.PlatformStand = false
        hum.AutoRotate = true
    end
end

local function StartFly()
    local char, root, hum = GetFlyParts()
    if not root or not hum or hum.Health <= 0 then
        return false
    end

    if FlyBodyVelocity then FlyBodyVelocity:Destroy() end
    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.Name = "KN_SecurityTestFly"
    FlyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    FlyBodyVelocity.P = 3500
    FlyBodyVelocity.Velocity = Vector3.zero
    FlyBodyVelocity.Parent = root

    FlyCurrentVelocity = Vector3.zero
    FlyEnabledLocal = true
    return true
end

local function GetFlyHorizontalInput(humanoid, camera)
    local input = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then input += Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then input += Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then input += Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then input += Vector3.new(1, 0, 0) end

    if input.Magnitude < 0.01 then
        local md = humanoid.MoveDirection
        if md.Magnitude > 0.01 then
            return Vector3.new(md.X, 0, md.Z).Unit
        end
    end

    if input.Magnitude < 0.01 then
        return Vector3.zero
    end

    input = input.Unit
    local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
    local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
    if forward.Magnitude < 0.01 or right.Magnitude < 0.01 then
        return Vector3.zero
    end

    forward = forward.Unit
    right = right.Unit
    return (right * input.X + forward * (-input.Z)).Unit
end

Toggle(MovementTab, "Fly Test", false, function(v)
    if v then
        if not StartFly() then
            Config.FlyEnabled = false
            Notify("Movement", "Fly bị từ chối: hãy chạy đúng ServerScript Studio.")
            return
        end
        Config.FlyEnabled = true
        Notify("Movement", "Fly ON — WASD / Space / Shift")
    else
        StopFly()
        Notify("Movement", "Fly OFF")
    end
end)

Slider(MovementTab, "Fly Speed", 10, 300, 60, function(v)
    Config.FlySpeed = v
end)

--========================================================--
-- FLY HIT TEST
-- Select a player in the current server and smoothly hover above them.
-- Combat damage is intentionally not automated here.
--========================================================--

local FlyHitEnabled = false
local FlyHitTarget = nil
local FlyHitHeight = 7
local FlyHitSpeed = 60

local function GetPlayerByName(name)
    if not name or name == "" then return nil end
    local needleName = name:lower()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Name:lower() == needleName or player.DisplayName:lower() == needleName then
                return player
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Name:lower():find(needleName, 1, true)
                or player.DisplayName:lower():find(needleName, 1, true) then
                return player
            end
        end
    end

    return nil
end

local function SetFlyHitTarget(player)
    if player == LocalPlayer then
        Notify("Fly Hit", "Không thể chọn chính bạn.")
        return false
    end

    if not player then
        Notify("Fly Hit", "Không tìm thấy player.")
        return false
    end

    FlyHitTarget = player
    Notify("Fly Hit", "Target: " .. player.Name)
    return true
end

local function StopFlyHit()
    FlyHitEnabled = false
    FlyHitTarget = nil
    Notify("Fly Hit", "OFF")
end

local function StartFlyHit()
    if not FlyHitTarget or FlyHitTarget == LocalPlayer then
        Notify("Fly Hit", "Hãy chọn một player trước.")
        return false
    end

    local targetCharacter = FlyHitTarget.Character
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

    if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
        Notify("Fly Hit", "Target chưa sẵn sàng.")
        return false
    end

    if not Config.FlyEnabled then
        if not StartFly() then
            Notify("Fly Hit", "Không thể khởi động Fly.")
            return false
        end
        Config.FlyEnabled = true
    end

    FlyHitEnabled = true
    Notify("Fly Hit", "ON → đang bay phía trên " .. FlyHitTarget.Name)
    return true
end

local function RefreshFlyHitPlayers(container, selectedLabel)
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local button = New("TextButton", {
                BackgroundColor3 = Theme.Panel2,
                Size = UDim2.new(1, 0, 0, 32),
                Font = Enum.Font.GothamSemibold,
                Text = "  " .. player.DisplayName .. "  @" .. player.Name,
                TextColor3 = Theme.Text,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = true
            }, container)
            Corner(button, 6)
            Outline(button, Theme.Stroke, 1)

            Connect(button.Activated, function()
                if SetFlyHitTarget(player) then
                    selectedLabel.Text = "Selected: " .. player.Name
                end
            end)
        end
    end
end

Connect(RunService.RenderStepped, function()
    if not Config.FlyEnabled or not FlyEnabledLocal or not FlyBodyVelocity then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local camera = Workspace.CurrentCamera
    if not root or not hum or not camera then return end

    if FlyHitEnabled then
        local targetCharacter = FlyHitTarget and FlyHitTarget.Character
        local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
        local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

        if not FlyHitTarget or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
            FlyHitEnabled = false
            Notify("Fly Hit", "Target không còn hợp lệ.")
            return
        end

        local targetPosition = targetRoot.Position + Vector3.new(0, FlyHitHeight, 0)
        local offset = targetPosition - root.Position
        local distance = offset.Magnitude

        if distance > 0.15 then
            local direction = offset.Unit
            local speed = math.min(FlyHitSpeed, 120)
            local desired = direction * math.min(speed, distance / math.max(0.016, 1 / 60))

            FlyCurrentVelocity = FlyCurrentVelocity:Lerp(
                desired,
                math.clamp(FlyAcceleration * 0.016, 0, 1)
            )
        else
            FlyCurrentVelocity = FlyCurrentVelocity:Lerp(Vector3.zero, 0.18)
        end

        FlyBodyVelocity.Velocity = FlyCurrentVelocity
        return
    end

    local horizontal = GetFlyHorizontalInput(hum, camera)
    local verticalInput = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        verticalInput = 1
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        verticalInput = -1
    end

    if root.Position.Y >= FlyMaxHeight and verticalInput > 0 then
        verticalInput = 0
    end

    -- Smooth, natural flight: no instant high-speed launch.
    local speed = math.min(Config.FlySpeed, 300)
    local verticalSpeed = math.min(FlyVerticalSpeed, speed)

    local targetVelocity =
        (horizontal * speed)
        + Vector3.new(0, verticalInput * verticalSpeed, 0)

    FlyCurrentVelocity = FlyCurrentVelocity:Lerp(
        targetVelocity,
        math.clamp(FlyAcceleration * 0.016, 0, 1)
    )

    FlyBodyVelocity.Velocity = FlyCurrentVelocity
end)

Slider(MovementTab, "Fly Max Height", 50, 3000, FlyMaxHeight, function(v)
    FlyMaxHeight = v
end)

New("TextLabel", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 40),
    Font = Enum.Font.Gotham,
    Text = "Fly: WASD/joystick = bay • Space = lên • Ctrl/Shift = xuống • chuyển động mượt",
    TextColor3 = Theme.SubText,
    TextSize = 10,
    TextWrapped = true
}, MovementTab)

Toggle(MovementTab, "Anti Ragdoll Test", false, function(v)
    Notify("Movement", v and "Ragdoll test protection ON" or "OFF")
end)

Toggle(MovementTab, "Trap Detection Test", false, function(v)
    Notify("Movement", v and "Trap detection ON" or "OFF")
end)

Connect(LocalPlayer.CharacterAdded, function(character)
    local hum = character:WaitForChild("Humanoid", 5)
    if hum and Config.SpeedEnabled then
        hum.WalkSpeed = Config.Speed

    end

    if Config.FlyEnabled then
        task.wait(0.25)
        if StartFly() then
            Config.FlyEnabled = true
        else
            Config.FlyEnabled = false
        end
    end
end)

-- Keep the test speed active if another local system changes Humanoid.WalkSpeed.
Connect(RunService.Heartbeat, function()
    if not Config.SpeedEnabled then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= Config.Speed then
        hum.WalkSpeed = Config.Speed
    end
end)

--========================================================--
-- EGG SCANNER
--========================================================--

Section(EggTab, "EGG SCANNER")

local EggStatus = New("TextLabel", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 62),
    Font = Enum.Font.Gotham,
    Text = "Eggs found: 0",
    TextColor3 = Theme.Text,
    TextSize = 11,
    TextWrapped = true
}, EggTab)

Corner(EggStatus, 7)

local function IsEgg(obj)
    local n = obj.Name:lower()

    return obj:IsA("Model")
        and (
            n:find("egg")
            or n:find("trung")
            or n:find("trứng")
        )
end

local function ScanEggs()
    local eggs = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if IsEgg(obj) then
            table.insert(eggs, obj)
        end
    end

    return eggs
end

Button(EggTab, "Scan All Eggs", function()
    local eggs = ScanEggs()

    local names = {}

    for i, egg in ipairs(eggs) do
        if i <= 8 then
            table.insert(names, egg.Name)
        end
    end

    EggStatus.Text =
        "Eggs found: " .. #eggs ..
        "\n" .. table.concat(names, ", ")

    Notify("Egg Scanner", "Found " .. #eggs .. " egg(s).")
end)

Toggle(EggTab, "Secret Priority", true, function(v)
    Config.EggFilters.Secret = v
end)

Toggle(EggTab, "Big Egg Filter", false, function(v)
    Config.EggFilters.Big = v
end)

Toggle(EggTab, "Mutation Filter", false, function(v)
    Config.EggFilters.Mutation = v
end)

Toggle(EggTab, "Parasite Filter", false, function(v)
    Config.EggFilters.Parasite = v
end)

Toggle(EggTab, "Monster Filter", false, function(v)
    Config.EggFilters.Monster = v
end)

Toggle(EggTab, "Event Egg Filter", false, function(v)
    Config.EggFilters.Event = v
end)

Button(EggTab, "Scan All Areas", function()
    local folders = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            if not folders[obj.Name] then
                folders[obj.Name] = true
            end
        end
    end

    local count = 0
    for _ in pairs(folders) do count += 1 end

    Notify("Area Scanner", "Detected " .. count .. " possible areas.")
end)

Button(EggTab, "Find Nearest Egg", function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not root then
        Notify("Egg Scanner", "Character chưa sẵn sàng.")
        return
    end

    local nearest, distance

    for _, egg in ipairs(ScanEggs()) do
        local part = egg.PrimaryPart
            or egg:FindFirstChildWhichIsA("BasePart", true)

        if part then
            local d = (part.Position - root.Position).Magnitude

            if not distance or d < distance then
                nearest = egg
                distance = d
            end
        end
    end

    if nearest then
        Notify("Nearest Egg", nearest.Name .. " | " .. math.floor(distance) .. " studs")
    else
        Notify("Egg Scanner", "Không tìm thấy egg.")
    end
end)

--========================================================--
-- ESP
--========================================================--

Section(ESPTab, "PLAYER / EGG ESP")

local function ClearESP()
    for object, data in pairs(ESPObjects) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        ESPObjects[object] = nil
    end
end

local function AddESP(object, label)
    if ESPObjects[object] then return end

    local adornee = object

    local highlight = Instance.new("Highlight")
    highlight.Name = "KN_TestESP"
    highlight.FillTransparency = .75
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Theme.Red
    highlight.FillColor = Theme.DarkRed
    highlight.Adornee = adornee
    highlight.Parent = Gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "KN_TestLabel"
    billboard.Size = UDim2.new(0, 180, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee =
        object:IsA("Model") and (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true))
        or nil
    billboard.Parent = Gui

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Theme.Text
    text.TextStrokeTransparency = .3
    text.TextSize = 12
    text.Text = label
    text.Parent = billboard

    ESPObjects[object] = {
        Highlight = highlight,
        Billboard = billboard,
        Text = text
    }
end

local function RefreshESP()
    ClearESP()

    if Config.PlayerESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                AddESP(p.Character, p.Name)
            end
        end
    end

    if Config.EggESP then
        for _, egg in ipairs(ScanEggs()) do
            AddESP(egg, egg.Name)
        end
    end
end

Toggle(ESPTab, "Player ESP", false, function(v)
    Config.PlayerESP = v
    RefreshESP()
end)

Toggle(ESPTab, "Egg ESP", false, function(v)
    Config.EggESP = v
    RefreshESP()
end)

Toggle(ESPTab, "Show Names", true, function(v)
    Config.ShowNames = v
end)

Toggle(ESPTab, "Show Distance", true, function(v)
    Config.ShowDistance = v
end)

Slider(ESPTab, "ESP Distance", 50, 2000, 500, function(v)
    Config.ESPDistance = v
end)

Button(ESPTab, "Refresh ESP", function()
    RefreshESP()
    Notify("ESP", "ESP refreshed.")
end)

--========================================================--
-- FLY HIT UI
--========================================================--

Section(CombatTab, "FLY HIT")

local FlyHitSelected = New("TextLabel", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 32),
    Font = Enum.Font.GothamSemibold,
    Text = "Selected: None",
    TextColor3 = Theme.Text,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, CombatTab)
Corner(FlyHitSelected, 6)
Outline(FlyHitSelected, Theme.Stroke, 1)

New("UIPadding", {
    PaddingLeft = UDim.new(0, 10)
}, FlyHitSelected)

local FlyHitPlayerList = New("ScrollingFrame", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 145),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Red
}, CombatTab)
Corner(FlyHitPlayerList, 7)
Outline(FlyHitPlayerList, Theme.Stroke, 1)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, FlyHitPlayerList)

New("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, FlyHitPlayerList)

Button(CombatTab, "Refresh Player List", function()
    RefreshFlyHitPlayers(FlyHitPlayerList, FlyHitSelected)
    Notify("Fly Hit", "Đã cập nhật danh sách server.")
end)

Slider(CombatTab, "Fly Hit Height", 3, 20, 7, function(v)
    FlyHitHeight = v
end)

Slider(CombatTab, "Fly Hit Speed", 10, 120, 60, function(v)
    FlyHitSpeed = v
end)

Toggle(CombatTab, "Fly Hit", false, function(v)
    if v then
        if not StartFlyHit() then
            return
        end
    else
        StopFlyHit()
        if Config.FlyEnabled then
            StopFly()
        end
    end
end)

Button(CombatTab, "Clear Fly Hit Target", function()
    FlyHitEnabled = false
    FlyHitTarget = nil
    FlyHitSelected.Text = "Selected: None"
    Notify("Fly Hit", "Target cleared.")
end)

-- Populate the list immediately.
RefreshFlyHitPlayers(FlyHitPlayerList, FlyHitSelected)

--========================================================--
-- COMBAT TEST
--========================================================--

Section(CombatTab, "COMBAT TESTING")

local TargetName = ""

TextBox(CombatTab, "Target Player", "Nhập tên player...", function(value)
    TargetName = value
    Notify("Combat", "Target = " .. value)
end)

Toggle(CombatTab, "Aim Test", false, function(v)
    Notify("Combat", v and "Aim test ON" or "OFF")
end)

Toggle(CombatTab, "Hitbox Visualization", false, function(v)
    Config.HitboxTest = v
end)

Slider(CombatTab, "Test Hitbox Size", 2, 100, 10, function(v)
    Config.HitboxSize = v
end)

Button(CombatTab, "Simulate Hit Check", function()
    local target = GetPlayerByName(TargetName)
    if not target then
        Notify("Security Test", "Target không hợp lệ.")
        return
    end

    local myChar = LocalPlayer.Character
    local targetChar = target.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

    if not myRoot or not targetRoot then
        Notify("Security Test", "Character chưa sẵn sàng.")
        return
    end

    local distance = (myRoot.Position - targetRoot.Position).Magnitude
    local inRange = distance <= Config.HitboxSize
    Notify("Security Test", inRange and ("HIT CHECK PASS • " .. math.floor(distance) .. " studs") or ("HIT CHECK BLOCK • " .. math.floor(distance) .. " studs"))
end)

Button(CombatTab, "Simulate Remote Spam", function()
    -- Deliberately local-only: useful for testing UI/rate-limit handling without
    -- sending malicious requests to a live server.
    local requests = 100
    local accepted = math.min(requests, 10)
    local blocked = requests - accepted
    Notify("Security Test", "Simulated " .. requests .. " requests • expected block: " .. blocked)
end)

Button(CombatTab, "Find Target", function()
    local target

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Name:lower():find(TargetName:lower(), 1, true) then
            target = p
            break
        end
    end

    if target then
        Notify("Combat", "Found: " .. target.Name)
    else
        Notify("Combat", "Không tìm thấy target.")
    end
end)

Button(CombatTab, "Run Hit Detection Test", function()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        Notify("Combat", "Character chưa sẵn sàng.")
        return
    end

    local hits = 0

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")

            if targetRoot and
                (targetRoot.Position - root.Position).Magnitude <= Config.HitboxSize then
                hits += 1
            end
        end
    end

    Notify("Combat Test", "Detected targets: " .. hits)
end)

--========================================================--
-- FPS BOOST
--========================================================--

Section(FPSTab, "PERFORMANCE")

local function ApplyGraphics(enabled)
    if enabled then
        OriginalLighting.GlobalShadows = Lighting.GlobalShadows
        OriginalLighting.Brightness = Lighting.Brightness

        Lighting.GlobalShadows = false
        Lighting.Brightness = 1

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") then
                obj.Enabled = false
            elseif obj:IsA("Trail") then
                obj.Enabled = false
            elseif obj:IsA("Beam") then
                obj.Enabled = false
            end
        end
    else
        if OriginalLighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        end

        if OriginalLighting.Brightness ~= nil then
            Lighting.Brightness = OriginalLighting.Brightness
        end
    end
end

Toggle(FPSTab, "Low Graphics", false, function(v)
    Config.LowGraphics = v
    ApplyGraphics(v)
end)

Toggle(FPSTab, "Disable Particles", false, function(v)
    Config.Particles = v

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            obj.Enabled = not v
        end
    end
end)

Toggle(FPSTab, "Disable Shadows", false, function(v)
    Config.Shadows = v
    Lighting.GlobalShadows = not v
end)

Button(FPSTab, "Performance Scan", function()
    local objects = #Workspace:GetDescendants()

    local emitters = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            emitters += 1
        end
    end

    Notify(
        "Performance",
        "Objects: " .. objects .. " | ParticleEmitters: " .. emitters
    )
end)

local FPSLabel = New("TextLabel", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 44),
    Font = Enum.Font.GothamBold,
    Text = "FPS: --",
    TextColor3 = Theme.Text,
    TextSize = 13
}, FPSTab)

Corner(FPSLabel, 7)

local fpsFrames = 0
local fpsClock = os.clock()

Connect(RunService.RenderStepped, function()
    fpsFrames += 1

    if os.clock() - fpsClock >= 1 then
        FPSLabel.Text = "FPS: " .. fpsFrames
        fpsFrames = 0
        fpsClock = os.clock()
    end
end)

--========================================================--
-- SECURITY TEST
--========================================================--

Section(ServerTab, "SECURITY TEST")

Button(ServerTab, "Run Client Tamper Scan", function()
    local checks = {
        "WalkSpeed authority",
        "Fly movement authority",
        "Target validation",
        "Remote rate limiting",
        "Server-side damage validation"
    }
    Notify("Security Scan", "Checklist: " .. #checks .. " server checks recommended.")
end)

Button(ServerTab, "Show Security Rules", function()
    Notify("Security", "Server must validate movement, targets, damage and request rate.")
end)

--========================================================--
-- SERVER
--========================================================--

Section(ServerTab, "SERVER INFO")

local ServerInfo = New("TextLabel", {
    BackgroundColor3 = Theme.Panel,
    Size = UDim2.new(1, 0, 0, 90),
    Font = Enum.Font.Gotham,
    TextColor3 = Theme.Text,
    TextSize = 11,
    TextWrapped = true
}, ServerTab)

Corner(ServerInfo, 7)

local function UpdateServerInfo()
    ServerInfo.Text =
        "PlaceId: " .. game.PlaceId ..
        "\nJobId: " .. game.JobId ..
        "\nPlayers: " .. #Players:GetPlayers()
end

UpdateServerInfo()

Button(ServerTab, "Refresh Server Info", function()
    UpdateServerInfo()
    Notify("Server", "Server info refreshed.")
end)

Button(ServerTab, "List Players", function()
    local names = {}

    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(names, p.Name)
    end

    Notify("Players", table.concat(names, ", "))
end)

--========================================================--
-- SETTINGS
--========================================================--

Section(SettingsTab, "SETTINGS")

Toggle(SettingsTab, "Notifications", true, function(v)
    Config.Notifications = v
end)

Button(SettingsTab, "Reset Movement", function()
    Config.Speed = 16
    Config.SpeedEnabled = false
    Config.FlyEnabled = false
    StopFly()

    local hum = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.WalkSpeed = 16
    end

    Notify("Settings", "Movement reset.")
end)

Button(SettingsTab, "Clear ESP", function()
    Config.PlayerESP = false
    Config.EggESP = false
    ClearESP()
    Notify("Settings", "ESP cleared.")
end)

Button(SettingsTab, "Restore Graphics", function()
    ApplyGraphics(false)

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            obj.Enabled = true
        elseif obj:IsA("Trail") then
            obj.Enabled = true
        elseif obj:IsA("Beam") then
            obj.Enabled = true
        end
    end

    Notify("Settings", "Graphics restored.")
end)

--========================================================--
-- MENU VISIBILITY
--========================================================--

local Open = New("TextButton", {
    BackgroundColor3 = Color3.fromRGB(67, 48, 98),
    BackgroundTransparency = 0.08,
    Position = UDim2.new(0, 15, .5, -25),
    Size = UDim2.new(0, 52, 0, 52),
    Font = Enum.Font.GothamBold,
    Text = "KN",
    TextColor3 = Theme.Text,
    TextSize = 14,
    Visible = false,
    AutoButtonColor = false,
    ZIndex = 100
}, Gui)
Corner(Open, 12)
Outline(Open, Color3.fromRGB(150, 119, 205), 1.2)

local function HideMenu()
    Main.Visible = false
    Open.Visible = true
end

local function ShowMenu()
    Main.Visible = true
    Open.Visible = false
end

Button(SettingsTab, "Close Menu", HideMenu)

--========================================================--
-- OPEN BUTTON
--========================================================--

Connect(Close.MouseButton1Click, HideMenu)
Connect(Open.MouseButton1Click, ShowMenu)

-- Mobile touch fallback.
Connect(Close.Activated, HideMenu)
Connect(Open.Activated, ShowMenu)

-- RightControl toggles the panel on keyboard.
Connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        if Main.Visible then
            HideMenu()
        else
            ShowMenu()
        end
    end
end)

--========================================================--
-- DRAG
--========================================================--

local dragging = false
local dragStart
local startPos

Connect(Top.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

Connect(UserInputService.InputChanged, function(input)
    if not dragging then return end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

Connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

--========================================================--
-- RESPAWN
--========================================================--

Connect(LocalPlayer.CharacterAdded, function()
    StopFly()
    task.wait(1)

    if Config.SpeedEnabled then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Config.Speed end
    end

    if Config.FlyEnabled then
        StartFly()
    end

    if Config.PlayerESP then
        task.wait(.5)
        RefreshESP()
    end
end)

Connect(Players.PlayerAdded, function()
    task.wait(.5)

    if Config.PlayerESP then
        RefreshESP()
    end

    RefreshFlyHitPlayers(FlyHitPlayerList, FlyHitSelected)
    UpdateServerInfo()
end)

Connect(Players.PlayerRemoving, function(player)
    if FlyHitTarget == player then
        FlyHitEnabled = false
        FlyHitTarget = nil
        FlyHitSelected.Text = "Selected: None"
        Notify("Fly Hit", "Target đã rời server.")
    end
    task.wait(.1)
    RefreshESP()
    RefreshFlyHitPlayers(FlyHitPlayerList, FlyHitSelected)
    UpdateServerInfo()
end)

Tabs.Main.Select()

Notify("Khang Nguyen", "Dragon Developer Panel v4 đã khởi động.")

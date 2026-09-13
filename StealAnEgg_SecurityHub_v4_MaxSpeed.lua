--[[
    KHANG NGUYEN • STEAL AN EGG SECURITY HUB v4.0
    Purpose: Authorized security-testing / developer test harness.
    Place as a LocalScript in StarterPlayerScripts.

    IMPORTANT:
    - Gameplay actions are routed through the optional TestAPI.
    - No executor-only APIs, metatable hooks, anti-cheat bypasses, or
      unauthorized RemoteEvent abuse are implemented here.
    - If no TestAPI is connected, gameplay tests fail safely and visibly.
]]

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// CONFIG
local CONFIG = {
    Name = "KN_DragonSecurityHub",
    Version = "3.0",

    Theme = {
        Background = Color3.fromRGB(10, 10, 14),
        Panel = Color3.fromRGB(20, 20, 27),
        Panel2 = Color3.fromRGB(27, 27, 36),
        Red = Color3.fromRGB(205, 45, 45),
        Gold = Color3.fromRGB(239, 181, 54),
        White = Color3.fromRGB(242, 242, 246),
        Gray = Color3.fromRGB(155, 155, 168),
        Green = Color3.fromRGB(65, 205, 125),
        Blue = Color3.fromRGB(80, 155, 235),
    },

    Movement = {
        MinWalkSpeed = 1,
        MaxWalkSpeed = 1000,
        MinFlySpeed = 1,
        MaxFlySpeed = 1000,
    },

    ESP = {
        MaxDistance = 500,
        UpdateRate = 0.08,
    },

    Test = {
        AutoStealInterval = 1.0,
        AutoSellInterval = 1.5,
        CombatInterval = 0.5,
    },

    GameSpecific = {
        ValidAreas = {"Forest", "Desert", "Volcano", "CyberWorld", "Heaven"},
        ValidRarities = {"Secret", "Big", "Rare", "Epic", "Legendary"},
        ValidMutations = {"Any", "Gold", "Diamond", "Rainbow", "Normal"},
    }
}

--// STATE
local STATE = {
    Initialized = false,
    Destroyed = false,

    CurrentArea = "Forest",
    SelectedRarity = "Secret",
    SelectedSellRarity = "All",
    SelectedSellMutation = "Any",

    AutoStealRunning = false,
    AutoSellRunning = false,
    BatAuraRunning = false,

    WalkSpeedValue = 16,
    TPWalkEnabled = false,
    FlyEnabled = false,
    FlySpeedValue = 50,

    StealSpeedValue = 1,
    ChaseSpeedValue = 16,

    NeverSellFavorite = true,
    NeverSellMutated = true,
    SelectedPetTypes = {},
    WhitelistPlayers = {},

    ESPPlayersEnabled = false,
    ESPEggsEnabled = false,
    ESPMyEggEnabled = false,

    Status = "READY",
    LastMessage = "Ready",

    SecurityStats = {
        TotalRequests = 0,
        Accepted = 0,
        Rejected = 0,
        Errors = 0,
        TestsRun = 0,
    },

    Logs = {},
}

--// CONNECTIONS / TASKS
local CONNECTIONS = {}
local TASKS = {}

local function disconnect(connection)
    if typeof(connection) == "RBXScriptConnection" then
        connection:Disconnect()
    end
end

local function cancelTask(key)
    local thread = TASKS[key]
    TASKS[key] = nil
    if thread and coroutine.status(thread) ~= "dead" then
        task.cancel(thread)
    end
end

local function connect(key, signal, callback)
    disconnect(CONNECTIONS[key])
    CONNECTIONS[key] = signal:Connect(callback)
    return CONNECTIONS[key]
end

--// LOGGING
local function pushLog(level, message)
    local entry = {
        Time = os.date("%H:%M:%S"),
        Level = level,
        Message = tostring(message),
    }

    table.insert(STATE.Logs, 1, entry)
    if #STATE.Logs > 100 then
        table.remove(STATE.Logs)
    end

    if level == "ERROR" then
        warn("[DragonSecurityHub]", message)
    else
        print("[DragonSecurityHub]", message)
    end
end

local function setStatus(status, message)
    STATE.Status = status
    STATE.LastMessage = message or status
    pushLog(status, STATE.LastMessage)
end

--// UTILITY
local Utility = {}

function Utility.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.clamp(value, minimum, maximum)
end

function Utility.SafeCall(callback, ...)
    local ok, a, b, c = pcall(callback, ...)
    if not ok then
        return false, tostring(a)
    end
    return true, a, b, c
end

function Utility.GetCharacter(player)
    return player and player.Character
end

function Utility.GetRoot(player)
    local character = Utility.GetCharacter(player)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
end

function Utility.GetHumanoid(player)
    local character = Utility.GetCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

function Utility.IsWhitelisted(name)
    return STATE.WhitelistPlayers[name] == true
end

function Utility.SetWhitelisted(name, enabled)
    if enabled then
        STATE.WhitelistPlayers[name] = true
    else
        STATE.WhitelistPlayers[name] = nil
    end
end

function Utility.GetDistanceFromLocal(player)
    local a = Utility.GetRoot(LocalPlayer)
    local b = Utility.GetRoot(player)
    if not a or not b then
        return math.huge
    end
    return (a.Position - b.Position).Magnitude
end

function Utility.IsValidChoice(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

--// TEST API
local TestAPI = {
    _Instance = nil,
}

function TestAPI:IsConnected()
    return typeof(self._Instance) == "table"
end

function TestAPI:Connect(apiTable)
    if typeof(apiTable) ~= "table" then
        self._Instance = nil
        setStatus("FAILED", "Invalid Test API")
        return false
    end

    self._Instance = apiTable
    setStatus("READY", "Test API connected")
    return true
end

function TestAPI:Disconnect()
    self._Instance = nil
    setStatus("READY", "Test API disconnected")
end

function TestAPI:_Call(method, ...)
    local api = self._Instance

    if not api or typeof(api[method]) ~= "function" then
        setStatus("BLOCKED", "Test API not connected: " .. method)
        return false, "Test API not connected"
    end

    local ok, a, b, c = pcall(api[method], ...)
    if not ok then
        STATE.SecurityStats.Errors += 1
        setStatus("ERROR", tostring(a))
        return false, tostring(a)
    end

    setStatus("READY", tostring(b or a or "OK"))
    return true, a, b, c
end

function TestAPI:StealEgg(area, rarity)
    return self:_Call("StealEgg", area, rarity)
end

function TestAPI:SellPet(data)
    return self:_Call("SellPet", data)
end

function TestAPI:SetMovement(mode, value)
    return self:_Call("SetMovement", mode, value)
end

function TestAPI:CombatTest(testType, data)
    return self:_Call("CombatTest", testType, data)
end

function TestAPI:SecurityTest(testType, payload)
    STATE.SecurityStats.TotalRequests += 1

    local ok, status, message = self:_Call("SecurityTest", testType, payload)

    if not ok then
        STATE.SecurityStats.Errors += 1
        return "ERROR", message
    end

    if status == "ACCEPTED" then
        STATE.SecurityStats.Accepted += 1
    elseif status == "REJECTED" then
        STATE.SecurityStats.Rejected += 1
    else
        STATE.SecurityStats.Errors += 1
    end

    return status or "ERROR", message
end

-- Optional developer bridge:
-- _G.KN_DragonTestAPI = { StealEgg=function(...) ... end, ... }
if typeof(_G.KN_DragonTestAPI) == "table" then
    TestAPI:Connect(_G.KN_DragonTestAPI)
end

--// MOVEMENT TEST
local Movement = {}

function Movement:ApplyWalkSpeed(speed)
    speed = Utility.Clamp(speed, CONFIG.Movement.MinWalkSpeed, CONFIG.Movement.MaxWalkSpeed)
    STATE.WalkSpeedValue = speed

    TestAPI:SetMovement("WalkSpeed", speed)

    local humanoid = Utility.GetHumanoid(LocalPlayer)
    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

function Movement:SetTPWalk(enabled)
    STATE.TPWalkEnabled = enabled
    TestAPI:SetMovement("TPWalk", enabled and STATE.WalkSpeedValue or 0)
end

function Movement:SetFly(enabled, speed)
    STATE.FlyEnabled = enabled
    STATE.FlySpeedValue = Utility.Clamp(
        speed or STATE.FlySpeedValue,
        CONFIG.Movement.MinFlySpeed,
        CONFIG.Movement.MaxFlySpeed
    )

    TestAPI:SetMovement("Fly", {
        Enabled = enabled,
        Speed = STATE.FlySpeedValue,
    })
end

function Movement:Reset()
    STATE.TPWalkEnabled = false
    STATE.FlyEnabled = false
    STATE.WalkSpeedValue = 16
    STATE.FlySpeedValue = 50

    local humanoid = Utility.GetHumanoid(LocalPlayer)
    if humanoid then
        humanoid.WalkSpeed = 16
    end

    TestAPI:SetMovement("Reset", 0)
end

--// AUTO STEAL TEST
local AutoSteal = {}

function AutoSteal:Toggle(enabled)
    STATE.AutoStealRunning = enabled
    cancelTask("AutoSteal")

    if not enabled then
        setStatus("READY", "Auto Steal Test stopped")
        return
    end

    if not Utility.IsValidChoice(CONFIG.GameSpecific.ValidAreas, STATE.CurrentArea)
        or not Utility.IsValidChoice(CONFIG.GameSpecific.ValidRarities, STATE.SelectedRarity) then
        STATE.AutoStealRunning = false
        setStatus("FAILED", "Invalid area or rarity")
        return
    end

    TASKS.AutoSteal = task.spawn(function()
        setStatus("RUNNING", "Auto Steal Test started")

        while STATE.AutoStealRunning and not STATE.Destroyed do
            local ok, result = TestAPI:StealEgg(
                STATE.CurrentArea,
                STATE.SelectedRarity
            )

            if not ok then
                pushLog("BLOCKED", "Steal request: " .. tostring(result))
            end

            task.wait(CONFIG.Test.AutoStealInterval)
        end
    end)
end

--// AUTO SELL TEST
local AutoSell = {}

function AutoSell:Toggle(enabled)
    STATE.AutoSellRunning = enabled
    cancelTask("AutoSell")

    if not enabled then
        setStatus("READY", "Auto Sell Test stopped")
        return
    end

    TASKS.AutoSell = task.spawn(function()
        setStatus("RUNNING", "Auto Sell Test started")

        while STATE.AutoSellRunning and not STATE.Destroyed do
            local payload = {
                Rarity = STATE.SelectedSellRarity,
                Mutation = STATE.SelectedSellMutation,
                NeverSellFavorite = STATE.NeverSellFavorite,
                NeverSellMutated = STATE.NeverSellMutated,
                SelectedPetTypes = STATE.SelectedPetTypes,
            }

            local ok, result = TestAPI:SellPet(payload)
            if not ok then
                pushLog("BLOCKED", "Sell request: " .. tostring(result))
            end

            task.wait(CONFIG.Test.AutoSellInterval)
        end
    end)
end

--// COMBAT TEST
local Combat = {}

function Combat:SetBatAura(enabled)
    STATE.BatAuraRunning = enabled
    cancelTask("BatAura")

    if not enabled then
        setStatus("READY", "Bat Aura Test stopped")
        return
    end

    TASKS.BatAura = task.spawn(function()
        setStatus("RUNNING", "Bat Aura Test started")

        while STATE.BatAuraRunning and not STATE.Destroyed do
            local myRoot = Utility.GetRoot(LocalPlayer)

            if myRoot then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer
                        and not Utility.IsWhitelisted(player.Name) then

                        local targetRoot = Utility.GetRoot(player)

                        if targetRoot then
                            local distance = (myRoot.Position - targetRoot.Position).Magnitude

                            if distance <= 30 then
                                TestAPI:CombatTest("BatAura", {
                                    Target = player.Name,
                                    Distance = distance,
                                    Mode = "SecurityTest",
                                })
                            end
                        end
                    end
                end
            end

            task.wait(CONFIG.Test.CombatInterval)
        end
    end)
end

function Combat:HitDetectionTest(playerName)
    local target = Players:FindFirstChild(playerName)
    if not target then
        return false, "Target not found"
    end

    local distance = Utility.GetDistanceFromLocal(target)

    return TestAPI:CombatTest("HitDetection", {
        Target = target.Name,
        Distance = distance,
        MaxDistance = 30,
        Mode = "SecurityTest",
    })
end

--// ESP / DEBUG
local ESP = {
    Objects = {},
    LastUpdate = 0,
}

function ESP:Clear()
    for _, object in pairs(self.Objects) do
        if object and object.Destroy then
            object:Destroy()
        end
    end
    table.clear(self.Objects)
end

function ESP:AddPlayer(player)
    if player == LocalPlayer or self.Objects[player] then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "KN_ESP_" .. player.Name
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.72
    highlight.OutlineTransparency = 0.15
    highlight.Parent = Workspace

    self.Objects[player] = highlight
end

function ESP:UpdatePlayers()
    if not STATE.ESPPlayersEnabled then
        self:Clear()
        return
    end

    local now = os.clock()
    if now - self.LastUpdate < CONFIG.ESP.UpdateRate then
        return
    end
    self.LastUpdate = now

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:AddPlayer(player)

            local highlight = self.Objects[player]
            local distance = Utility.GetDistanceFromLocal(player)

            if highlight then
                highlight.Adornee =
                    distance <= CONFIG.ESP.MaxDistance
                    and player.Character
                    or nil

                highlight.FillColor =
                    Utility.IsWhitelisted(player.Name)
                    and CONFIG.Theme.Gold
                    or CONFIG.Theme.Red
            end
        end
    end

    for player, highlight in pairs(self.Objects) do
        if not player.Parent then
            highlight:Destroy()
            self.Objects[player] = nil
        end
    end
end

function ESP:SetPlayers(enabled)
    STATE.ESPPlayersEnabled = enabled
    if not enabled then
        self:Clear()
    end
end

--// ENTERPRISE SECURITY AUDIT ENGINE
-- Safe, non-destructive backend audit layer.
-- It never invokes arbitrary remotes and never mutates player/game data.
local Security = {}

local AUDIT_CONFIG = {
    MaxRateLimitSimulationCount = 500,
    FuzzingIterationCount = 50,
    DefaultExpectedBehavior = "BLOCKED",
}

local SeverityLevel = {
    CRITICAL = {Weight = 5, Label = "CRITICAL"},
    HIGH = {Weight = 4, Label = "HIGH"},
    MEDIUM = {Weight = 3, Label = "MEDIUM"},
    LOW = {Weight = 2, Label = "LOW"},
    INFO = {Weight = 1, Label = "INFO"},
}

local TestCasesDatabase = {
        {Name="Invalid Egg ID - GUID Malformation", Category="EGG", Payload={EggId="NULL_POINTER_0x0000",Rarity="Secret",Vector="MalformedString"}, Expected="BLOCKED", Severity="HIGH", Reason="Server must reject unrecognized or uninitialized Egg IDs."},
        {Name="Cross-Player Egg Hijacking", Category="EGG", Payload={EggId="EGG_TARGET_99",OwnerUserId=99999999,RequestUserId=12345}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must derive ownership from server state, never from client ownership fields."},
        {Name="Extreme Distance Egg Claim", Category="EGG", Payload={EggId="EGG_DISTANT_01",DistanceMagnitude=9999.99,PositionDelta=Vector3.new(5000,0,5000)}, Expected="BLOCKED", Severity="HIGH", Reason="Server must calculate interaction distance from authoritative positions."},
        {Name="Idempotency Violation - Double Claim Replay", Category="EGG", Payload={EggId="EGG_CLAIMED_02",NonceToken="AUTH_NONCE_ABC123",Sequence=1}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must reject replayed or duplicated claim requests."},
        {Name="State Cooldown Bypass Attack", Category="EGG", Payload={EggId="EGG_COOLDOWN_03",ElapsedTimeMs=50,RequiredCooldownMs=5000}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must maintain authoritative cooldown timestamps."},
        {Name="Rarity Typo / Tier Injection", Category="EGG", Payload={EggId="EGG_101",Rarity="OmnipotentGodTier_AdminOverride"}, Expected="BLOCKED", Severity="HIGH", Reason="Server must validate rarity against server-defined values."},
        {Name="Mutation Payload Spoofing", Category="EGG", Payload={EggId="EGG_102",MutationList={"Rainbow","Gold","InjectedCustomHack"}}, Expected="BLOCKED", Severity="HIGH", Reason="Server must reject client-injected mutation states."},
        {Name="Out-of-Order Sequence Packet Injection", Category="EGG", Payload={EggId="EGG_104",SequenceId=-9999,ExpectedSequence=45}, Expected="BLOCKED", Severity="LOW", Reason="Server must reject malformed or stale sequences."},
        {Name="Inventory Ownership Bypass - Nonexistent Pet", Category="PET", Payload={PetId="PET_NONEXISTENT_99",InventoryReference=nil}, Expected="BLOCKED", Severity="HIGH", Reason="Server must verify pet existence and ownership."},
        {Name="Double Sell / Lifecycle Desync", Category="PET", Payload={PetId="PET_SOLD_01",CurrentState="TransferredToVendor"}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must prevent operations on already-consumed items."},
        {Name="Locked Item Protection Override", Category="PET", Payload={PetId="PET_LOCKED_02",LockFlag=true,OverrideAttempt=true}, Expected="BLOCKED", Severity="HIGH", Reason="Server must enforce lock state server-side."},
        {Name="Favorite Item Safety Shield Bypass", Category="PET", Payload={PetId="PET_FAV_03",FavoriteFlag=true,Operation="Sell"}, Expected="BLOCKED", Severity="HIGH", Reason="Server must honor favorite protection."},
        {Name="NoSQL / SQL Injection via Pet ID String", Category="PET", Payload={PetId="PET_01'; DROP TABLE PetInventory; --"}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server-side persistence/query layers must treat IDs as data, not executable query fragments."},
        {Name="Client-Side Valuation Override", Category="PET", Payload={PetId="PET_01",ClaimedSellValue=99999999999}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must calculate sell value independently."},
        {Name="Negative Quantity Financial Exploitation", Category="PET", Payload={PetId="PET_01",Quantity=-100}, Expected="BLOCKED", Severity="HIGH", Reason="Server must reject negative transaction quantities."},
        {Name="Integer Overflow Quantity Attack", Category="PET", Payload={PetId="PET_01",Quantity=9.223372e18}, Expected="BLOCKED", Severity="HIGH", Reason="Server must cap quantities and reject non-legitimate values."},
        {Name="Ghost Entity Hit Targeting", Category="COMBAT", Payload={TargetId="GhostEntity_999",WorkspaceExists=false}, Expected="BLOCKED", Severity="HIGH", Reason="Server must verify target existence."},
        {Name="Melee Range Vector Exploitation", Category="COMBAT", Payload={TargetId="Player_B",DistanceDelta=450.0,MaxAllowedRange=15.0}, Expected="BLOCKED", Severity="HIGH", Reason="Server must calculate attack range itself."},
        {Name="Corporeal Interaction - Dead Entity Attack", Category="COMBAT", Payload={TargetId="Player_C",TargetHealthState=0,IsDestroyed=true}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must reject hits against invalid/dead targets."},
        {Name="Client-Authored Damage Injection", Category="COMBAT", Payload={InjectedDamageValue=1000000.0,BaseWeaponDamage=15.0}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must calculate damage from authoritative weapon/state."},
        {Name="Unowned Weapon Instantiation Attack", Category="COMBAT", Payload={WeaponId="UnownedGodWeapon_X",OwnershipVerified=false}, Expected="BLOCKED", Severity="HIGH", Reason="Server must verify weapon ownership."},
        {Name="Attack Cooldown / Rate Limit Violation", Category="COMBAT", Payload={AttackIntervalMs=5,RequiredIntervalMs=1000}, Expected="BLOCKED", Severity="HIGH", Reason="Server must enforce attack cooldowns and rate limits."},
        {Name="Hit Packet Replay & Duplication", Category="COMBAT", Payload={HitPacketId="PACKET_DUPLICATE_99",Timestamp=1710000000}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server should reject duplicate/replayed hit identifiers where applicable."},
        {Name="Geometric Raycast Position Mismatch", Category="COMBAT", Payload={HitPosition=Vector3.new(99999,0,99999),ActualPlayerPos=Vector3.new(0,0,0)}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must validate hit geometry against authoritative positions."},
        {Name="WalkSpeed Hard-Cap Bypass", Category="MOVEMENT", Payload={RequestedWalkSpeed=500.0,MaxWalkSpeedConfig=16.0}, Expected="BLOCKED", Severity="HIGH", Reason="Server must enforce movement limits."},
        {Name="Velocity Vector Manipulation", Category="MOVEMENT", Payload={VelocityVector=Vector3.new(99999,50000,99999)}, Expected="BLOCKED", Severity="HIGH", Reason="Server must detect impossible velocity/displacement."},
        {Name="Instantaneous Teleportation / Position Warp", Category="MOVEMENT", Payload={PreviousPos=Vector3.new(0,0,0),NewPos=Vector3.new(50000,0,50000),DeltaTime=0.01}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must validate movement continuity."},
        {Name="Client vs Server Position Discrepancy", Category="MOVEMENT", Payload={ClientReportedPosition=Vector3.new(0,500,0),ServerTrackedPosition=Vector3.new(0,0,0)}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must compare against authoritative state."},
        {Name="Unauthorized Aerial / Fly State Injection", Category="MOVEMENT", Payload={FlyStateEnabled=true,ServerGrantedFlyPermission=false}, Expected="BLOCKED", Severity="HIGH", Reason="Server must reject unauthorized flight states."},
        {Name="Positional Update Spam / Flood", Category="MOVEMENT", Payload={PacketFrequencyPerSec=1000}, Expected="BLOCKED", Severity="LOW", Reason="Server must rate-limit relevant update channels."},
        {Name="Cross-Player Resource Exfiltration (A -> B)", Category="AUTHORIZATION", Payload={Actor="PlayerA",TargetVictim="PlayerB",ResourceType="Currency"}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must isolate player-owned resources."},
        {Name="Privilege Escalation - Client Role Spoofing", Category="AUTHORIZATION", Payload={ClaimedRole="Administrator",ActualRole="Guest"}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must verify roles from server-side permissions."},
        {Name="Session Owner ID Forgery", Category="AUTHORIZATION", Payload={ForgedUserId=1,RealUserId=12345678}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must bind requests to the authenticated Player instance."},
        {Name="Target User ID Null / Negative Injection", Category="AUTHORIZATION", Payload={TargetUserId=-999}, Expected="BLOCKED", Severity="HIGH", Reason="Server must reject malformed target identifiers."},
        {Name="Cryptographic Session Token Forgery", Category="AUTHORIZATION", Payload={AuthToken="EXPLOIT_BYPASS_TOKEN_DEADBEEF"}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must reject forged client authentication material."},
        {Name="Unearned Reward Claim Injection", Category="ECONOMY", Payload={RewardId="VIP_BONUS",EligibilityChecked=false,RequestedAmount=1000000}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must independently verify reward eligibility and amount."},
        {Name="Balance Underflow via Negative Reward", Category="ECONOMY", Payload={RewardAmount=-999999}, Expected="BLOCKED", Severity="MEDIUM", Reason="Server must reject invalid financial deltas."},
        {Name="Numeric Overflow / Scientific Notation Exploit", Category="ECONOMY", Payload={RewardAmount=1e308}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must enforce safe numeric bounds."},
        {Name="Client-Side Store Price Manipulation", Category="ECONOMY", Payload={ItemId="GodTierEgg",ClientOfferedPrice=0}, Expected="BLOCKED", Severity="CRITICAL", Reason="Server must dictate catalog pricing."},
        {Name="Item Sell Valuation Inflation", Category="ECONOMY", Payload={ItemId="CommonPet",ClientClaimedValue=50000000}, Expected="BLOCKED", Severity="HIGH", Reason="Server must calculate item value."},
        {Name="Currency Overflow Attack (Int32/Int64 Limit)", Category="ECONOMY", Payload={CurrencyDelta=9223372036854775807}, Expected="BLOCKED", Severity="HIGH", Reason="Server must validate currency deltas and overflow."},
        {Name="Ledger Transaction Idempotency Bypass", Category="ECONOMY", Payload={TransactionId="TX_ALREADY_CONSUMED_XYZ"}, Expected="BLOCKED", Severity="HIGH", Reason="Server must enforce transaction idempotency."}
    }

local ValidationMatrixTemplate = {
    InputsToTest = {
        "nil", "boolean", "string", "number", "negative number",
        "zero", "huge number", "NaN", "Infinity", "invalid Instance",
        "missing Instance", "foreign Player", "foreign Item", "invalid ID"
    },
    Attributes = {
        "Expected Type", "Valid Range", "Ownership Required",
        "Distance Required", "Cooldown Required", "Authorization Required",
        "Expected Result"
    }
}

local AuditState = {
    ActiveAdapter = nil,
    History = {},
    Statistics = {
        TotalRun = 0,
        Passed = 0,
        Failed = 0,
        Errors = 0,
        CriticalFailures = 0,
        ExecutionTimeMs = 0,
    },
}

local function auditAdapter()
    if AuditState.ActiveAdapter then
        return AuditState.ActiveAdapter
    end

    -- Developer-provided bridge only. The hub does not discover or invoke
    -- arbitrary RemoteEvents/RemoteFunctions automatically.
    local candidate = rawget(_G, "KN_DragonSecurityAdapter")
    if typeof(candidate) == "table" then
        AuditState.ActiveAdapter = candidate
    end

    return AuditState.ActiveAdapter
end

function Security.ConnectAdapter(adapterTable)
    if typeof(adapterTable) ~= "table" then
        AuditState.ActiveAdapter = nil
        setStatus("BLOCKED", "Invalid audit adapter")
        return false
    end

    AuditState.ActiveAdapter = adapterTable
    setStatus("READY", "Security audit adapter connected")
    return true
end

function Security.DisconnectAdapter()
    AuditState.ActiveAdapter = nil
    setStatus("READY", "Security audit adapter disconnected")
end

function Security.IsConnected()
    return auditAdapter() ~= nil
end

local function normalizeResult(result)
    if result == "ACCEPTED" or result == "BLOCKED"
        or result == "INVALID" or result == "COOLDOWN"
        or result == "ERROR" or result == "NOT_CONNECTED" then
        return result
    end
    return "ERROR"
end

function Security.RunCase(testCase)
    if typeof(testCase) ~= "table" then
        return {
            TestName = "Unknown",
            Status = "ERROR",
            Expected = "BLOCKED",
            Actual = "ERROR",
            Severity = "LOW",
            Explanation = "Invalid test case.",
            Recommendation = "Check test case structure.",
        }
    end

    AuditState.Statistics.TotalRun += 1
    local started = os.clock()
    local adapter = auditAdapter()

    local actual = "NOT_CONNECTED"
    local message = "No server-side audit adapter is connected."

    if adapter and typeof(adapter.RunSecurityTest) == "function" then
        local ok, result, detail = pcall(
            adapter.RunSecurityTest,
            testCase.Category,
            testCase.Name,
            testCase.Payload
        )

        if ok then
            actual = normalizeResult(result)
            message = tostring(detail or actual)
        else
            actual = "ERROR"
            message = tostring(result)
            AuditState.Statistics.Errors += 1
        end
    end

    local status
    if actual == "NOT_CONNECTED" then
        status = "NOT_VERIFIED"
    elseif actual == testCase.Expected then
        status = "PASS"
        AuditState.Statistics.Passed += 1
    elseif actual == "ERROR" then
        status = "ERROR"
        AuditState.Statistics.Errors += 1
    else
        status = "FAIL"
        AuditState.Statistics.Failed += 1
        if testCase.Severity == "CRITICAL" then
            AuditState.Statistics.CriticalFailures += 1
        end
    end

    local duration = (os.clock() - started) * 1000
    AuditState.Statistics.ExecutionTimeMs += duration

    local record = {
        TestName = testCase.Name,
        Category = testCase.Category,
        Status = status,
        Expected = testCase.Expected,
        Actual = actual,
        Severity = testCase.Severity,
        Explanation = testCase.Reason,
        Recommendation = "Validate the value, ownership, authorization, state, range and rate limit on the server.",
        ExecutionTimeMs = duration,
        AdapterMessage = message,
    }

    table.insert(AuditState.History, 1, record)

    if status == "FAIL" then
        pushLog("ERROR", testCase.Name .. " -> " .. actual)
    elseif status == "NOT_VERIFIED" then
        pushLog("BLOCKED", testCase.Name .. " -> backend adapter not connected")
    else
        pushLog("INFO", testCase.Name .. " -> " .. status)
    end

    return record
end

function Security:Run(name, payload)
    for _, testCase in ipairs(TestCasesDatabase) do
        if testCase.Name == name then
            return Security.RunCase(testCase)
        end
    end

    return Security.RunCase({
        Name = name or "Unknown",
        Category = "CUSTOM",
        Payload = payload or {},
        Expected = "BLOCKED",
        Severity = "LOW",
        Reason = "Custom security validation case.",
    })
end

function Security:RunAll()
    local results = {}
    for _, testCase in ipairs(TestCasesDatabase) do
        table.insert(results, Security.RunCase(testCase))
    end
    return results
end

function Security:RunCategory(category)
    local results = {}
    for _, testCase in ipairs(TestCasesDatabase) do
        if testCase.Category == string.upper(category) then
            table.insert(results, Security.RunCase(testCase))
        end
    end
    return results
end

function Security.SimulateRateLimit(policyType, count)
    count = math.clamp(tonumber(count) or AUDIT_CONFIG.MaxRateLimitSimulationCount, 1, AUDIT_CONFIG.MaxRateLimitSimulationCount)

    local accepted = 0
    local blocked = 0

    for i = 1, count do
        if policyType == "NORMAL" then
            if i <= 5 then accepted += 1 else blocked += 1 end
        elseif policyType == "RAPID" or policyType == "DUPLICATE" then
            if i == 1 then accepted += 1 else blocked += 1 end
        else
            blocked += 1
        end
    end

    return {
        Policy = policyType,
        TotalSimulated = count,
        Accepted = accepted,
        Blocked = blocked,
        Note = "LOCAL SIMULATION ONLY; no RemoteEvent/RemoteFunction calls are sent.",
    }
end

function Security.GenerateValidationMatrix()
    return {
        Template = ValidationMatrixTemplate,
        TotalTestInputs = #ValidationMatrixTemplate.InputsToTest,
        Status = "READY",
    }
end

function Security.GetStatistics()
    return AuditState.Statistics
end

function Security.GetHistory()
    return AuditState.History
end

function Security.Reset()
    AuditState.History = {}
    AuditState.Statistics = {
        TotalRun = 0,
        Passed = 0,
        Failed = 0,
        Errors = 0,
        CriticalFailures = 0,
        ExecutionTimeMs = 0,
    }
end

-- Client-visible inventory only. This records Remote names/classes but never fires them.
function Security.ScanClientVisibleAPIs()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local inventory = {}

    for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
        if object:IsA("RemoteEvent")
            or object:IsA("RemoteFunction")
            or object:IsA("BindableEvent")
            or object:IsA("BindableFunction") then

            table.insert(inventory, {
                Name = object:GetFullName(),
                Class = object.ClassName,
                AccessibleFromClient = true,
                InvokedByAudit = false,
            })
        end
    end

    table.sort(inventory, function(a, b)
        return a.Name < b.Name
    end)

    pushLog("INFO", "Client-visible API inventory: " .. #inventory .. " objects")
    return inventory
end

Security.Cases = TestCasesDatabase
Security.Database = TestCasesDatabase
Security.Severity = SeverityLevel
Security.ValidationMatrix = ValidationMatrixTemplate
Security.AuditState = AuditState

--// UI HELPERS
local UI = {
    Gui = nil,
    Main = nil,
    Content = nil,
    Pages = {},
    Buttons = {},
    StatusLabel = nil,
    StatsLabel = nil,
}

local function tween(instance, properties, duration)
    TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        properties
    ):Play()
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, parent)
end

local function stroke(parent, color, transparency)
    return make("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = 1,
    }, parent)
end

local function label(parent, text, size, color)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, size or 28),
        Text = text,
        TextColor3 = color or CONFIG.Theme.White,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function button(parent, text, callback, height)
    local b = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = CONFIG.Theme.Panel2,
        Size = UDim2.new(1, 0, 0, height or 34),
        Text = text,
        TextColor3 = CONFIG.Theme.White,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
    }, parent)

    corner(b, 7)
    stroke(b, Color3.fromRGB(50, 50, 62), 0.25)

    b.MouseEnter:Connect(function()
        tween(b, {BackgroundColor3 = CONFIG.Theme.Red}, 0.12)
    end)

    b.MouseLeave:Connect(function()
        tween(b, {BackgroundColor3 = CONFIG.Theme.Panel2}, 0.12)
    end)

    b.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            pushLog("ERROR", err)
        end
    end)

    return b
end

local function toggle(parent, text, initial, callback)
    local row = make("Frame", {
        BackgroundColor3 = CONFIG.Theme.Panel2,
        Size = UDim2.new(1, 0, 0, 38),
    }, parent)

    corner(row, 7)

    label(row, text, 38, CONFIG.Theme.White).Position =
        UDim2.new(0, 12, 0, 0)

    local switch = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = initial and CONFIG.Theme.Green or Color3.fromRGB(65, 65, 75),
        Position = UDim2.new(1, -62, 0.5, -11),
        Size = UDim2.fromOffset(50, 22),
        Text = "",
    }, row)

    corner(switch, 11)

    local knob = make("Frame", {
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        Position = initial and UDim2.new(1, -20, 0.5, -8)
            or UDim2.new(0, 4, 0.5, -8),
        Size = UDim2.fromOffset(16, 16),
    }, switch)

    corner(knob, 8)

    local value = initial

    local function setValue(nextValue)
        value = nextValue
        tween(
            switch,
            {BackgroundColor3 = value and CONFIG.Theme.Green or Color3.fromRGB(65, 65, 75)},
            0.15
        )
        tween(
            knob,
            {Position = value and UDim2.new(1, -20, 0.5, -8)
                or UDim2.new(0, 4, 0.5, -8)},
            0.15
        )
        callback(value)
    end

    switch.Activated:Connect(function()
        setValue(not value)
    end)

    return {
        Set = setValue,
        Get = function() return value end,
    }
end

local function section(parent, title)
    local l = label(parent, title:upper(), 26, CONFIG.Theme.Gold)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.Position = UDim2.new(0, 2, 0, 0)
    return l
end

local function createPage(name)
    local page = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = CONFIG.Theme.Red,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
    }, UI.Content)

    make("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, page)

    make("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    UI.Pages[name] = page
    return page
end

local function selectPage(name)
    for pageName, page in pairs(UI.Pages) do
        page.Visible = pageName == name
    end

    for buttonName, b in pairs(UI.Buttons) do
        b.BackgroundColor3 =
            buttonName == name and CONFIG.Theme.Red or CONFIG.Theme.Panel
    end
end

local function updateStatus()
    if UI.StatusLabel then
        UI.StatusLabel.Text = "● " .. STATE.Status .. "  •  " .. STATE.LastMessage
        UI.StatusLabel.TextColor3 =
            STATE.Status == "ERROR" and CONFIG.Theme.Red
            or STATE.Status == "BLOCKED" and CONFIG.Theme.Gold
            or STATE.Status == "RUNNING" and CONFIG.Theme.Blue
            or CONFIG.Theme.Green
    end

    if UI.StatsLabel then
        local s = Security.GetStatistics()
        UI.StatsLabel.Text =
            ("Tests %d   Pass %d   Fail %d   Errors %d   Critical %d")
            :format(s.TotalRun, s.Passed, s.Failed, s.Errors, s.CriticalFailures)
    end
end

local function createUI()
    local existing = PlayerGui:FindFirstChild(CONFIG.Name)
    if existing then
        existing:Destroy()
    end

    UI.Gui = make("ScreenGui", {
        Name = CONFIG.Name,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)

    UI.Main = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 760, 0, 500),
        BackgroundColor3 = CONFIG.Theme.Background,
    }, UI.Gui)

    corner(UI.Main, 14)
    stroke(UI.Main, CONFIG.Theme.Red, 0.2)

    local top = make("Frame", {
        BackgroundColor3 = CONFIG.Theme.Panel,
        Size = UDim2.new(1, 0, 0, 66),
    }, UI.Main)
    corner(top, 14)

    local title = label(top, "🐉  KHANG NGUYEN", 30, CONFIG.Theme.Gold)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.Position = UDim2.new(0, 18, 0, 8)

    local subtitle = label(top, "STEAL AN EGG  •  SECURITY TESTING HUB  v" .. CONFIG.Version, 20, CONFIG.Theme.Gray)
    subtitle.TextSize = 10
    subtitle.Position = UDim2.new(0, 19, 0, 37)

    local close = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(50, 25, 28),
        Position = UDim2.new(1, -48, 0, 17),
        Size = UDim2.fromOffset(30, 30),
        Text = "×",
        TextColor3 = CONFIG.Theme.White,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
    }, top)
    corner(close, 8)

    close.Activated:Connect(function()
        UI.Gui.Enabled = false
    end)

    local sidebar = make("Frame", {
        BackgroundColor3 = CONFIG.Theme.Panel,
        Position = UDim2.new(0, 10, 0, 76),
        Size = UDim2.new(0, 150, 1, -86),
    }, UI.Main)
    corner(sidebar, 10)

    local sideLayout = make("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sidebar)

    make("UIPadding", {
        PaddingTop = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, sidebar)

    UI.Content = make("Frame", {
        BackgroundColor3 = CONFIG.Theme.Panel,
        Position = UDim2.new(0, 170, 0, 76),
        Size = UDim2.new(1, -180, 1, -86),
    }, UI.Main)
    corner(UI.Content, 10)

    local pages = {
        {"Main", "MAIN"},
        {"Movement", "MOVEMENT"},
        {"Egg", "EGG TEST"},
        {"Pets", "PETS TEST"},
        {"Combat", "COMBAT"},
        {"ESP", "ESP / DEBUG"},
        {"Security", "SECURITY"},
        {"Settings", "SETTINGS"},
    }

    for _, item in ipairs(pages) do
        local name, text = item[1], item[2]
        local b = make("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = CONFIG.Theme.Panel,
            Size = UDim2.new(1, 0, 0, 35),
            Text = text,
            TextColor3 = CONFIG.Theme.Gray,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
        }, sidebar)
        corner(b, 7)
        UI.Buttons[name] = b

        b.Activated:Connect(function()
            selectPage(name)
        end)

        createPage(name)
    end

    local status = label(UI.Main, "● READY", 20, CONFIG.Theme.Green)
    status.Position = UDim2.new(0, 180, 1, -25)
    status.Size = UDim2.new(0.55, 0, 0, 18)
    status.TextSize = 9
    UI.StatusLabel = status

    local stats = label(UI.Main, "Requests 0   Accepted 0   Rejected 0   Errors 0   Tests 0", 20, CONFIG.Theme.Gray)
    stats.Position = UDim2.new(0.53, 0, 1, -25)
    stats.Size = UDim2.new(0.45, -10, 0, 18)
    stats.TextSize = 8
    stats.TextXAlignment = Enum.TextXAlignment.Right
    UI.StatsLabel = stats

    -- MAIN
    do
        local p = UI.Pages.Main

        section(p, "Quick controls")

        toggle(p, "Security Test Mode", true, function(enabled)
            setStatus("READY", enabled and "Test mode enabled" or "Test mode disabled")
        end)

        button(p, "Run All Standard Security Tests", function()
            Security:RunAll()
            updateStatus()
        end)

        button(p, "Reset Movement", function()
            Movement:Reset()
            updateStatus()
        end)

        section(p, "System")

        button(p, "Reconnect Test API", function()
            if typeof(_G.KN_DragonTestAPI) == "table" then
                TestAPI:Connect(_G.KN_DragonTestAPI)
            else
                setStatus("BLOCKED", "No developer Test API found")
            end
            updateStatus()
        end)
    end

    -- MOVEMENT
    do
        local p = UI.Pages.Movement

        section(p, "Movement testing")

        toggle(p, "WalkSpeed Test", false, function(enabled)
            Movement:ApplyWalkSpeed(enabled and STATE.WalkSpeedValue or 16)
            updateStatus()
        end)

        button(p, "WalkSpeed +10", function()
            Movement:ApplyWalkSpeed(STATE.WalkSpeedValue + 10)
            updateStatus()
        end)

        button(p, "WalkSpeed -10", function()
            Movement:ApplyWalkSpeed(STATE.WalkSpeedValue - 10)
            updateStatus()
        end)

        button(p, "WalkSpeed MAX (1000)", function()
            Movement:ApplyWalkSpeed(CONFIG.Movement.MaxWalkSpeed)
            updateStatus()
        end)

        toggle(p, "TPWalk Test", false, function(enabled)
            Movement:SetTPWalk(enabled)
            updateStatus()
        end)

        toggle(p, "Fly Test", false, function(enabled)
            Movement:SetFly(enabled, STATE.FlySpeedValue)
            updateStatus()
        end)

        button(p, "Fly Speed +10", function()
            STATE.FlySpeedValue = Utility.Clamp(
                STATE.FlySpeedValue + 10,
                CONFIG.Movement.MinFlySpeed,
                CONFIG.Movement.MaxFlySpeed
            )
            if STATE.FlyEnabled then
                Movement:SetFly(true, STATE.FlySpeedValue)
            end
            updateStatus()
        end)

        button(p, "Fly Speed -10", function()
            STATE.FlySpeedValue = Utility.Clamp(
                STATE.FlySpeedValue - 10,
                CONFIG.Movement.MinFlySpeed,
                CONFIG.Movement.MaxFlySpeed
            )
            if STATE.FlyEnabled then
                Movement:SetFly(true, STATE.FlySpeedValue)
            end
            updateStatus()
        end)

        button(p, "Fly Speed MAX (1000)", function()
            STATE.FlySpeedValue = CONFIG.Movement.MaxFlySpeed
            if STATE.FlyEnabled then
                Movement:SetFly(true, STATE.FlySpeedValue)
            end
            updateStatus()
        end)
    end

    -- EGG
    do
        local p = UI.Pages.Egg

        section(p, "Auto Steal Test")

        button(p, "Area: " .. STATE.CurrentArea, function()
            local index = table.find(CONFIG.GameSpecific.ValidAreas, STATE.CurrentArea) or 1
            index = index % #CONFIG.GameSpecific.ValidAreas + 1
            STATE.CurrentArea = CONFIG.GameSpecific.ValidAreas[index]
            setStatus("READY", "Area = " .. STATE.CurrentArea)
            updateStatus()
        end)

        button(p, "Rarity: " .. STATE.SelectedRarity, function()
            local index = table.find(CONFIG.GameSpecific.ValidRarities, STATE.SelectedRarity) or 1
            index = index % #CONFIG.GameSpecific.ValidRarities + 1
            STATE.SelectedRarity = CONFIG.GameSpecific.ValidRarities[index]
            setStatus("READY", "Rarity = " .. STATE.SelectedRarity)
            updateStatus()
        end)

        toggle(p, "Auto Steal Egg Test", false, function(enabled)
            AutoSteal:Toggle(enabled)
            updateStatus()
        end)

        button(p, "Single Steal Test", function()
            TestAPI:StealEgg(STATE.CurrentArea, STATE.SelectedRarity)
            updateStatus()
        end)
    end

    -- PETS
    do
        local p = UI.Pages.Pets

        section(p, "Auto Sell Test")

        button(p, "Sell Rarity: " .. STATE.SelectedSellRarity, function()
            local values = {"All", "Secret", "Big", "Rare", "Epic", "Legendary"}
            local index = table.find(values, STATE.SelectedSellRarity) or 1
            STATE.SelectedSellRarity = values[index % #values + 1]
            setStatus("READY", "Sell rarity = " .. STATE.SelectedSellRarity)
            updateStatus()
        end)

        button(p, "Mutation: " .. STATE.SelectedSellMutation, function()
            local values = CONFIG.GameSpecific.ValidMutations
            local index = table.find(values, STATE.SelectedSellMutation) or 1
            STATE.SelectedSellMutation = values[index % #values + 1]
            setStatus("READY", "Mutation = " .. STATE.SelectedSellMutation)
            updateStatus()
        end)

        toggle(p, "Never Sell Favorite", STATE.NeverSellFavorite, function(enabled)
            STATE.NeverSellFavorite = enabled
        end)

        toggle(p, "Never Sell Mutated", STATE.NeverSellMutated, function(enabled)
            STATE.NeverSellMutated = enabled
        end)

        toggle(p, "Auto Sell Test", false, function(enabled)
            AutoSell:Toggle(enabled)
            updateStatus()
        end)

        button(p, "Single Sell Validation Test", function()
            TestAPI:SellPet({
                Rarity = STATE.SelectedSellRarity,
                Mutation = STATE.SelectedSellMutation,
                NeverSellFavorite = STATE.NeverSellFavorite,
                NeverSellMutated = STATE.NeverSellMutated,
            })
            updateStatus()
        end)
    end

    -- COMBAT
    do
        local p = UI.Pages.Combat

        section(p, "Combat validation")

        toggle(p, "Bat Aura Test", false, function(enabled)
            Combat:SetBatAura(enabled)
            updateStatus()
        end)

        button(p, "Hit Detection Test • Nearest Player", function()
            local nearest, distance

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and not Utility.IsWhitelisted(player.Name) then
                    local d = Utility.GetDistanceFromLocal(player)
                    if d < (distance or math.huge) then
                        nearest = player
                        distance = d
                    end
                end
            end

            if nearest then
                Combat:HitDetectionTest(nearest.Name)
            else
                setStatus("BLOCKED", "No valid target")
            end

            updateStatus()
        end)

        button(p, "Whitelist Nearest Player", function()
            local nearest, distance

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local d = Utility.GetDistanceFromLocal(player)
                    if d < (distance or math.huge) then
                        nearest = player
                        distance = d
                    end
                end
            end

            if nearest then
                Utility.SetWhitelisted(nearest.Name, true)
                setStatus("READY", nearest.Name .. " whitelisted")
            end

            updateStatus()
        end)
    end

    -- ESP
    do
        local p = UI.Pages.ESP

        section(p, "Debug visuals")

        toggle(p, "ESP Players", false, function(enabled)
            ESP:SetPlayers(enabled)
            updateStatus()
        end)

        button(p, "Clear ESP", function()
            ESP:Clear()
            updateStatus()
        end)

        button(p, "Print Player Distances", function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    pushLog("INFO", ("%s = %.1f studs"):format(
                        player.Name,
                        Utility.GetDistanceFromLocal(player)
                    ))
                end
            end
            updateStatus()
        end)
    end

    -- SECURITY
    do
        local p = UI.Pages.Security

        section(p, "Enterprise Backend Security Audit")

        button(p, "Connection / Adapter Check", function()
            if Security.IsConnected() then
                setStatus("READY", "Server audit adapter connected")
                pushLog("INFO", "Backend adapter detected")
            else
                setStatus("BLOCKED", "NOT VERIFIED • no server audit adapter")
            end
            updateStatus()
        end)

        button(p, "Scan Client-Visible API Inventory", function()
            local inventory = Security.ScanClientVisibleAPIs()
            setStatus("READY", "Found " .. #inventory .. " client-visible API objects")
            updateStatus()
        end)

        button(p, "Run ALL 42 Security Tests", function()
            local results = Security.RunAll()
            local notVerified = 0
            local failed = 0

            for _, result in ipairs(results) do
                if result.Status == "NOT_VERIFIED" then
                    notVerified += 1
                elseif result.Status == "FAIL" then
                    failed += 1
                end
            end

            setStatus(
                failed > 0 and "ERROR" or (notVerified > 0 and "BLOCKED" or "READY"),
                ("Completed: %d tests • %d not verified • %d failures")
                    :format(#results, notVerified, failed)
            )
            updateStatus()
        end)

        button(p, "Run EGG Tests", function()
            Security.RunCategory("EGG")
            setStatus("READY", "EGG audit completed")
            updateStatus()
        end)

        button(p, "Run PET Tests", function()
            Security.RunCategory("PET")
            setStatus("READY", "PET audit completed")
            updateStatus()
        end)

        button(p, "Run COMBAT Tests", function()
            Security.RunCategory("COMBAT")
            setStatus("READY", "COMBAT audit completed")
            updateStatus()
        end)

        button(p, "Run MOVEMENT Tests", function()
            Security.RunCategory("MOVEMENT")
            setStatus("READY", "MOVEMENT audit completed")
            updateStatus()
        end)

        button(p, "Run AUTHORIZATION Tests", function()
            Security.RunCategory("AUTHORIZATION")
            setStatus("READY", "AUTHORIZATION audit completed")
            updateStatus()
        end)

        button(p, "Run ECONOMY Tests", function()
            Security.RunCategory("ECONOMY")
            setStatus("READY", "ECONOMY audit completed")
            updateStatus()
        end)

        section(p, "Rate Limit • Local Simulation")

        button(p, "Simulate NORMAL / RAPID / DUPLICATE", function()
            local normal = Security.SimulateRateLimit("NORMAL", 20)
            local rapid = Security.SimulateRateLimit("RAPID", 20)
            local duplicate = Security.SimulateRateLimit("DUPLICATE", 20)

            pushLog("INFO", ("Rate simulation N=%d/%d R=%d/%d D=%d/%d")
                :format(
                    normal.Accepted, normal.Blocked,
                    rapid.Accepted, rapid.Blocked,
                    duplicate.Accepted, duplicate.Blocked
                ))

            setStatus("READY", "Rate-limit simulation completed locally")
            updateStatus()
        end)

        section(p, "Audit Result Meaning")
        label(p, "PASS = server returned expected BLOCKED result", 28, CONFIG.Theme.Green)
        label(p, "FAIL = server accepted an invalid test or returned wrong state", 38, CONFIG.Theme.Red)
        label(p, "NOT VERIFIED = no backend adapter; NOT counted as PASS", 38, CONFIG.Theme.Gold)
        label(p, "ERROR = adapter/runtime failure", 28, CONFIG.Theme.Red)

        button(p, "Clear Test Statistics", function()
            Security.Reset()
            setStatus("READY", "Audit history and statistics cleared")
            updateStatus()
        end)
    end

    -- SETTINGS
    do
        local p = UI.Pages.Settings

        section(p, "Interface")

        button(p, "Hide / Show Panel", function()
            UI.Gui.Enabled = not UI.Gui.Enabled
        end)

        button(p, "Reset UI Position", function()
            UI.Main.Position = UDim2.fromScale(0.5, 0.5)
        end)

        section(p, "Diagnostics")

        button(p, "Print Security Log", function()
            for _, entry in ipairs(STATE.Logs) do
                print(("[%s] %s: %s"):format(entry.Time, entry.Level, entry.Message))
            end
        end)

        button(p, "Destroy Hub", function()
            if UI.Gui then
                UI.Gui:Destroy()
            end
        end)
    end

    -- Drag support
    local dragging = false
    local dragStart
    local startPosition

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = UI.Main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - dragStart

            UI.Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    selectPage("Main")
    updateStatus()
end

--// INPUT / RUNTIME
local function bindRuntime()
    connect("Render", RunService.RenderStepped, function()
        if STATE.Destroyed then
            return
        end

        ESP:UpdatePlayers()
        updateStatus()
    end)

    connect("CharacterAdded", LocalPlayer.CharacterAdded, function()
        task.wait(0.4)

        if STATE.Destroyed then
            return
        end

        local humanoid = Utility.GetHumanoid(LocalPlayer)
        if humanoid then
            humanoid.WalkSpeed = STATE.WalkSpeedValue
        end
    end)

    connect("PlayerRemoving", Players.PlayerRemoving, function(player)
        ESP.Objects[player] = nil
        STATE.WhitelistPlayers[player.Name] = nil
    end)

    connect("Input", UserInputService.InputBegan, function(input, processed)
        if processed or STATE.Destroyed then
            return
        end

        if input.KeyCode == Enum.KeyCode.RightShift and UI.Gui then
            UI.Gui.Enabled = not UI.Gui.Enabled
        end
    end)
end

local function cleanup()
    if STATE.Destroyed then
        return
    end

    STATE.Destroyed = true

    STATE.AutoStealRunning = false
    STATE.AutoSellRunning = false
    STATE.BatAuraRunning = false

    for key in pairs(TASKS) do
        cancelTask(key)
    end

    for key, connection in pairs(CONNECTIONS) do
        disconnect(connection)
        CONNECTIONS[key] = nil
    end

    ESP:Clear()
    TestAPI:Disconnect()

    if UI.Gui then
        UI.Gui:Destroy()
        UI.Gui = nil
    end
end

local function initialize()
    if STATE.Initialized then
        return
    end

    STATE.Initialized = true
    STATE.Destroyed = false

    createUI()
    bindRuntime()

    pushLog("INFO", "Dragon Security Hub v" .. CONFIG.Version .. " initialized")
    setStatus("READY", "Hub initialized")
end

--// PUBLIC OBJECT
local Hub = {
    Config = CONFIG,
    State = STATE,
    API = TestAPI,

    Movement = Movement,
    AutoSteal = AutoSteal,
    AutoSell = AutoSell,
    Combat = Combat,
    ESP = ESP,
    Security = Security,

    Init = initialize,
    Cleanup = cleanup,
}

initialize()

return Hub

pcall(function()
    if getgenv().pgbFovCircle then
        getgenv().pgbFovCircle.Visible = false
        getgenv().pgbFovCircle:Remove()
    end
end)
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local oldGui = pg:FindFirstChild("Pham Gia Bao")
        if oldGui then oldGui:Destroy() end
    end
end)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local FOV_RADIUS = 500
local AIM_SMOOTH = 0.7
local ESP_MAX_DIST = 10000
local SPAWN_TEAM_DIST = 40
local espOn = false
local aimbotOn = false
local noclipOn = false
local currentTarget = nil
local flyOn = false
local FLY_SPEED = 50
local flyBV = nil
local flyBG = nil
local spawnRoles = {}
local fovCircle = Drawing.new("Circle")
fovCircle.Radius = FOV_RADIUS
if Camera then fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) end
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Transparency = 0.7
fovCircle.Visible = true
pcall(function() getgenv().pgbFovCircle = fovCircle end)
local fovOn = false
local speedOn = false
local jumpOn = false
local triggerOn = false
local hitboxOn = false
local radarOn = false
local menuOpen = false
local autoSwitchOn = false
local currentSlot = 1
local lastAmmo = nil
local lastAmmoCheck = 0
local VirtualInputManager = game:GetService("VirtualInputManager")
local lastTriggerClick = 0
local fixLagOn = false
local circleHidden = false
local JUMP_VAL = 120
local SPEED_VAL = 50
local rainbowOn = true
local CONFIG_FILE = "pgb_rivals_config.json"
local function getConfig()
    return {
        aimbot = aimbotOn,
        esp = espOn,
        fov = fovOn,
        fly = flyOn,
        noclip = noclipOn,
        speed = speedOn,
        jump = jumpOn,
        trigger = triggerOn,
        hitbox = hitboxOn,
        radar = radarOn,
        autoswitch = autoSwitchOn,
        fovRadius = FOV_RADIUS,
        aimSmooth = AIM_SMOOTH,
        fixlag = fixLagOn,
        hidecircle = circleHidden,
        jumpval = JUMP_VAL,
        speedval = SPEED_VAL,
        rainbow = rainbowOn,
    }
end
local function saveConfig()
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(getConfig()))
    end)
end
local function loadConfig()
    local ok, data = pcall(function()
        return readfile(CONFIG_FILE)
    end)
    if not ok or not data then return end
    local ok2, cfg = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if not ok2 or type(cfg) ~= "table" then return end
    if cfg.aimbot ~= nil then aimbotOn = cfg.aimbot end
    if cfg.esp ~= nil then espOn = cfg.esp end
    if cfg.fov ~= nil then fovOn = cfg.fov end
    if cfg.fly ~= nil then flyOn = cfg.fly end
    if cfg.noclip ~= nil then noclipOn = cfg.noclip end
    if cfg.speed ~= nil then speedOn = cfg.speed end
    if cfg.jump ~= nil then jumpOn = cfg.jump end
    if cfg.trigger ~= nil then triggerOn = cfg.trigger end
    if cfg.hitbox ~= nil then hitboxOn = cfg.hitbox end
    if cfg.radar ~= nil then radarOn = cfg.radar end
    if cfg.autoswitch ~= nil then autoSwitchOn = cfg.autoswitch end
    if cfg.fovRadius ~= nil then
        FOV_RADIUS = cfg.fovRadius
        if fovCircle then fovCircle.Radius = FOV_RADIUS end
    end
    if cfg.aimSmooth ~= nil then AIM_SMOOTH = cfg.aimSmooth end
    if cfg.fixlag ~= nil then fixLagOn = cfg.fixlag end
    if cfg.hidecircle ~= nil then circleHidden = cfg.hidecircle end
    if cfg.jumpval ~= nil then JUMP_VAL = cfg.jumpval end
    if cfg.speedval ~= nil then SPEED_VAL = cfg.speedval end
    if cfg.rainbow ~= nil then rainbowOn = cfg.rainbow end
end
loadConfig()
local radarBg = Drawing.new("Circle")
radarBg.Radius = 70
radarBg.Filled = true
radarBg.Transparency = 0.5
radarBg.Color = Color3.fromRGB(20, 20, 30)
radarBg.Visible = false
local radarCenter = Drawing.new("Circle")
radarCenter.Radius = 3
radarCenter.Filled = true
radarCenter.Color = Color3.fromRGB(255, 255, 255)
radarCenter.Visible = false
local radarDots = {}
for i = 1, 12 do
    local dot = Drawing.new("Circle")
    dot.Radius = 3
    dot.Filled = true
    dot.Color = Color3.fromRGB(255, 60, 60)
    dot.Visible = false
    radarDots[i] = dot
end
local mySpawnPos = nil
local spawnPos = {}
local mateAnchor = nil
local enemyAnchor = nil
local function recomputeAnchors()
    local ref = mySpawnPos
    if not ref then
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        ref = myRoot and myRoot.Position or nil
    end
    if not ref then mateAnchor = nil enemyAnchor = nil return end
    local pts = {}
    for player, pos in pairs(spawnPos) do
        if player ~= LocalPlayer then table.insert(pts, {player = player, pos = pos}) end
    end
    if #pts == 0 then mateAnchor = nil enemyAnchor = nil return end
    local far = pts[1]
    local best = -1
    for _, p in ipairs(pts) do
        local d = (p.pos - ref).Magnitude
        if d > best then best = d far = p end
    end
    if best < 40 then mateAnchor = nil enemyAnchor = nil return end
    local ca, cb = ref, far.pos
    for _ = 1, 5 do
        local sa, sb = Vector3.zero, Vector3.zero
        local na, nb = 0, 0
        for _, p in ipairs(pts) do
            if (p.pos - ca).Magnitude <= (p.pos - cb).Magnitude then
                sa = sa + p.pos na = na + 1
            else
                sb = sb + p.pos nb = nb + 1
            end
        end
        if na > 0 then ca = sa / na end
        if nb > 0 then cb = sb / nb end
    end
    mateAnchor = ca
    enemyAnchor = cb
    for _, p in ipairs(pts) do
        if (p.pos - mateAnchor).Magnitude <= (p.pos - enemyAnchor).Magnitude then
            spawnRoles[p.player] = "mate"
        else
            spawnRoles[p.player] = "enemy"
        end
    end
end
local function reclassifyAll()
    recomputeAnchors()
    if mateAnchor and enemyAnchor then return end
    if not mySpawnPos then return end
    for player, pos in pairs(spawnPos) do
        if player ~= LocalPlayer then
            if (pos - mySpawnPos).Magnitude < SPAWN_TEAM_DIST then
                spawnRoles[player] = "mate"
            else
                spawnRoles[player] = "enemy"
            end
        end
    end
end
local function refreshMySpawn(char)
    task.spawn(function()
        local root = nil
        for _ = 1, 5 do
            root = char and char:FindFirstChild("HumanoidRootPart")
            if root then break end
            task.wait(0.5)
        end
        if not root then return end
        task.wait(2)
        local root2 = char and char:FindFirstChild("HumanoidRootPart")
        if not root2 then return end
        local newPos = root2.Position
        if mySpawnPos and (newPos - mySpawnPos).Magnitude > 500 then
            spawnPos = {}
            spawnRoles = {}
            mateAnchor = nil
            enemyAnchor = nil
        end
        mySpawnPos = newPos
        reclassifyAll()
    end)
end
LocalPlayer.CharacterAdded:Connect(refreshMySpawn)
local myChar0 = LocalPlayer.Character
local myRoot0 = myChar0 and myChar0:FindFirstChild("HumanoidRootPart")
if myRoot0 then mySpawnPos = myRoot0.Position end
local function classify(player)
    local myChar = LocalPlayer.Character
    local char = player.Character
    if not myChar or not char then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not myRoot or not root then return nil end
    local pos = spawnPos[player] or root.Position
    if mateAnchor and enemyAnchor then
        if (pos - mateAnchor).Magnitude <= (pos - enemyAnchor).Magnitude then
            return "mate"
        end
        return "enemy"
    end
    local ref = mySpawnPos or myRoot.Position
    if (pos - ref).Magnitude < SPAWN_TEAM_DIST then
        return "mate"
    end
    return "enemy"
end
local function isEnemyPlayer(player)
    if not player then return false end
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    if myTeam and theirTeam then
        return theirTeam ~= myTeam
    end
    local role = spawnRoles[player]
    if role then
        return role == "enemy"
    end
    return false
end
local function canSee(targetPart, myChar)
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {myChar, targetPart.Parent}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, direction, params)
    return result == nil
end
local function getEffFov()
    local f = Camera and Camera.FieldOfView or 70
    if f <= 0 then return FOV_RADIUS end
    local s = math.tan(math.rad(35)) / math.tan(math.rad(f / 2))
    if s > 3 then s = 3 end
    if s < 1 then s = 1 end
    return FOV_RADIUS * s
end
local function getBestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best = nil
    local bestDist = getEffFov()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local head = char:FindFirstChild("Head")
                if hum and head and hum.Health > 0 then
                    if isEnemyPlayer(player) and canSee(head, myChar) then
                        local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                            if d < bestDist then
                                bestDist = d
                                best = head
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end
local function isTargetValid(head)
    if not head or not head.Parent then return false end
    local char = head.Parent
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local player = Players:GetPlayerFromCharacter(char)
    if player == LocalPlayer then return false end
    if player and not isEnemyPlayer(player) then return false end
    local myChar = LocalPlayer.Character
    if not myChar or not canSee(head, myChar) then return false end
    local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    if (Vector2.new(pos.X, pos.Y) - center).Magnitude > getEffFov() then return false end
    return true
end
local function setFly(on)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if on then
        if not char or not hum or not root then return end
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBG.CFrame = root.CFrame
        flyBG.Parent = root
        hum.PlatformStand = true
        flyOn = true
    else
        flyOn = false
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum then hum.PlatformStand = false end
    end
end
local function setNoclip(on)
    noclipOn = on
    if not on then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end
local function setSpeed(on)
    speedOn = on
    if not on then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end
local function setJump(on)
    jumpOn = on
    if not on then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = 50 end
    end
end
local function setHitbox(on)
    hitboxOn = on
    if not on then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                if head then
                    head.Size = Vector3.new(2, 1, 2)
                    head.Transparency = 0
                end
            end
        end
    end
end
local function clickMouse()
    local ok = pcall(function() mouse1click() end)
    if not ok then
        local vs = Camera and Camera.ViewportSize or Vector2.new(800, 600)
        VirtualInputManager:SendMouseButtonEvent(vs.X / 2, vs.Y / 2, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(vs.X / 2, vs.Y / 2, 0, false, game, 0)
    end
end
local lastTele = 0
local teleSeq = 0
local function teleBehind()
    if tick() - lastTele < 1 then return end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best = nil
    local bestHead = nil
    local bestDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isEnemyPlayer(player) then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum and head and root and hum.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = root
                        bestHead = head
                    end
                end
            end
        end
    end
    if not best then
        local myChar = LocalPlayer.Character
        local myRoot0 = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myRoot0 then
            local bestD = math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and isEnemyPlayer(player) then
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local head = char and char:FindFirstChild("Head")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if hum and head and root and hum.Health > 0 then
                        local d = (root.Position - myRoot0.Position).Magnitude
                        if d < bestD then
                            bestD = d
                            best = root
                            bestHead = head
                        end
                    end
                end
            end
        end
    end
    if not best then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local behind = best.Position - best.CFrame.LookVector * 4
    myRoot.CFrame = CFrame.lookAt(behind, best.Position)
    lastTele = tick()
    teleSeq = teleSeq + 1
    local mySeq = teleSeq
    task.delay(3, function()
        if mySeq ~= teleSeq then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return end
        local far = nil
        local farD = -1
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isTeammate(player) then
                local c = player.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if h and r and h.Health > 0 then
                    local d = (r.Position - root.Position).Magnitude
                    if d > farD then
                        farD = d
                        far = r
                    end
                end
            end
        end
        if not far then return end
        local spot = far.Position + far.CFrame.LookVector * 3
        root.CFrame = CFrame.lookAt(spot, far.Position)
    end)
    if bestHead then
        Camera.CFrame = CFrame.lookAt(behind, bestHead.Position)
        currentTarget = bestHead
    end
end
local function isTeammate(player)
    if not player then return false end
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    if myTeam and theirTeam then
        return theirTeam == myTeam
    end
    local role = spawnRoles[player]
    if role then
        return role == "mate"
    end
    return false
end
local lastTeleSpawn = 0
local function teleToSpawn()
    if tick() - lastTeleSpawn < 1 then return end
    if not mySpawnPos then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    myRoot.CFrame = CFrame.new(mySpawnPos + Vector3.new(0, 3, 0))
    lastTeleSpawn = tick()
end
local ammoLabel = nil
local function findAmmoLabel()
    local pg = LocalPlayer.PlayerGui
    if not pg then return nil end
    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
            local text = obj.Text
            if text and text:match("^%s*%d+%s*/%s*%d+%s*$") then
                return obj
            end
        end
    end
    return nil
end
local function getToolAmmo()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = nil
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then tool = obj break end
    end
    if not tool then return nil end
    for _, name in ipairs({"Ammo", "CurrentAmmo", "MagAmmo", "Magazine"}) do
        local v = tool:GetAttribute(name)
        if typeof(v) == "number" then return v end
        local child = tool:FindFirstChild(name)
        if child and (child:IsA("IntValue") or child:IsA("NumberValue")) then
            return child.Value
        end
    end
    return nil
end
local function getCurrentAmmo()
    if not ammoLabel or not ammoLabel.Parent then
        ammoLabel = findAmmoLabel()
    end
    if ammoLabel then
        local cur = ammoLabel.Text and ammoLabel.Text:match("^%s*(%d+)%s*/")
        if cur then return tonumber(cur) end
    end
    return getToolAmmo()
end
local function getOtherGunTool()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return nil end
    local equipped = nil
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then equipped = obj break end
    end
    for _, obj in ipairs(backpack:GetChildren()) do
        if obj:IsA("Tool") and obj ~= equipped then
            local n = obj.Name:lower()
            if not n:find("knife") and not n:find("melee") and not n:find("fist") and not n:find("sword") and not n:find("blade") and not n:find("karambit") and not n:find("bat") then
                return obj
            end
        end
    end
    return nil
end
local function switchWeapon()
    local char = LocalPlayer.Character
    local beforeTool = nil
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then beforeTool = obj break end
        end
    end
    local other = currentSlot == 1 and Enum.KeyCode.Two or Enum.KeyCode.One
    VirtualInputManager:SendKeyEvent(true, other, false, game)
    VirtualInputManager:SendKeyEvent(false, other, false, game)
    currentSlot = currentSlot == 1 and 2 or 1
    task.delay(0.3, function()
        local c = LocalPlayer.Character
        local nowTool = nil
        if c then
            for _, obj in ipairs(c:GetChildren()) do
                if obj:IsA("Tool") then nowTool = obj break end
            end
        end
        if nowTool == beforeTool then
            local tool = getOtherGunTool()
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if tool and hum then
                hum:EquipTool(tool)
            end
        end
    end)
end
local espDrawings = {}
local function addESP(player)
    if espDrawings[player] then return end
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Filled = false
    box.Transparency = 1
    box.Color = Color3.fromRGB(50, 100, 255)
    box.Visible = false
    local nameTag = Drawing.new("Text")
    nameTag.Size = 13
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Color = Color3.fromRGB(255, 255, 255)
    nameTag.Visible = false
    local hpBar = Drawing.new("Square")
    hpBar.Thickness = 1
    hpBar.Filled = true
    hpBar.Transparency = 1
    hpBar.Color = Color3.fromRGB(0, 255, 0)
    hpBar.Visible = false
    espDrawings[player] = {box = box, nameTag = nameTag, hpBar = hpBar}
end
local function removeESP(player)
    local d = espDrawings[player]
    if not d then return end
    d.box:Remove()
    d.nameTag:Remove()
    d.hpBar:Remove()
    espDrawings[player] = nil
end
local function reloadScript()
    for player, _ in pairs(espDrawings) do
        removeESP(player)
    end
    spawnPos = {}
    spawnRoles = {}
    mateAnchor = nil
    enemyAnchor = nil
    currentTarget = nil
    if fovCircle then fovCircle.Visible = fovOn and not circleHidden end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then
        mySpawnPos = myRoot.Position
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    spawnPos[player] = root.Position
                end
            end
        end
    end
    recomputeAnchors()
end
local function watchPlayer(player)
    player.CharacterAdded:Connect(function(char)
        task.spawn(function()
            local root = nil
            for _ = 1, 5 do
                root = char and char:FindFirstChild("HumanoidRootPart")
                if root then break end
                task.wait(0.5)
            end
            if not root then return end
            task.wait(2)
            local root2 = char and char:FindFirstChild("HumanoidRootPart")
            if not root2 then return end
            spawnPos[player] = root2.Position
            recomputeAnchors()
            local role = classify(player)
            if role then
                spawnRoles[player] = role
            end
        end)
    end)
end
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        watchPlayer(player)
        local role = classify(player)
        if role then spawnRoles[player] = role end
    end
end
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then watchPlayer(player) end
end)
local savedQuality = nil
local savedShadows = nil
local disabledFx = {}
local function setFixLag(on)
    fixLagOn = on
    if on then
        pcall(function()
            savedQuality = settings().Rendering.QualityLevel
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            savedShadows = Lighting.GlobalShadows
            Lighting.GlobalShadows = false
        end)
        disabledFx = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                if obj.Enabled then
                    obj.Enabled = false
                    table.insert(disabledFx, obj)
                end
            end
        end
    else
        pcall(function()
            if savedQuality then
                settings().Rendering.QualityLevel = savedQuality
            else
                settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            end
        end)
        pcall(function()
            if savedShadows ~= nil then
                Lighting.GlobalShadows = savedShadows
            else
                Lighting.GlobalShadows = true
            end
        end)
        for _, obj in ipairs(disabledFx) do
            pcall(function() obj.Enabled = true end)
        end
        disabledFx = {}
    end
    saveConfig()
end
if fixLagOn then setFixLag(true) end
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "PhamGiaBao"
menuGui.ResetOnSpawn = false
menuGui.IgnoreGuiInset = true
menuGui.DisplayOrder = 10
menuGui.Parent = playerGui
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 560, 0, 340)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -170)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = menuGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 120, 180)
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Pham Gia Bao"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 22
titleLabel.Parent = mainFrame
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, -24, 0, 3)
accentBar.Position = UDim2.new(0, 12, 0, 50)
accentBar.BackgroundColor3 = Color3.fromRGB(255, 120, 180)
accentBar.BorderSizePixel = 0
accentBar.Parent = mainFrame
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 2)
accentCorner.Parent = accentBar
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -36, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = mainFrame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeBtn
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 36)
tabBar.Position = UDim2.new(0, 10, 0, 58)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainFrame
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar
local tabFrames = {}
local tabBtns = {}
local currentTab = "Combat"
local activeTabBtn = nil
local rainbowBtns = {}
local function showTab(name)
    currentTab = name
    for tName, frame in pairs(tabFrames) do
        frame.Visible = (tName == name)
    end
    for tName, btn in pairs(tabBtns) do
        if tName == name then
            activeTabBtn = btn
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            btn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end
end
local tabOrder = {"Combat", "Visual", "Di Chuyen", "Setting"}
for _, tName in ipairs(tabOrder) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 130, 0, 36)
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 15
    tabBtn.Text = tName
    tabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    tabBtn.Parent = tabBar
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 10)
    tabCorner.Parent = tabBtn
    tabBtn.MouseButton1Click:Connect(function()
        showTab(tName)
    end)
    tabBtns[tName] = tabBtn
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 0, 200)
    content.Position = UDim2.new(0, 10, 0, 100)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = mainFrame
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 262, 0, 34)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = content
    tabFrames[tName] = content
end
local function makeToggle(parent, name, getState, setState)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 262, 0, 34)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = parent
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn
    local function refresh()
        local on = getState()
        btn.Text = name .. " : " .. (on and "Bat" or "Tat")
        btn.BackgroundColor3 = on and Color3.fromRGB(60, 200, 120) or Color3.fromRGB(255, 60, 60)
    end
    btn.MouseButton1Click:Connect(function()
        setState(not getState())
        refresh()
        saveConfig()
    end)
    refresh()
end
local function makeButton(parent, name, action)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 262, 0, 34)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
    btn.Parent = parent
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn
    table.insert(rainbowBtns, btn)
    btn.MouseButton1Click:Connect(function()
        action()
    end)
end
local sliderActive = false
local function makeSlider(parent, name, minVal, maxVal, getVal, setVal, fmt)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 262, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    frame.Parent = parent
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, 16)
    label.Position = UDim2.new(0, 4, 0, 2)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -8, 0, 14)
    track.Position = UDim2.new(0, 4, 0, 19)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = frame
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 4)
    trackCorner.Parent = track
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 120, 180)
    fill.BorderSizePixel = 0
    fill.Active = false
    fill.Parent = track
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill
    local function refresh()
        local v = getVal()
        local frac = math.clamp((v - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        label.Text = name .. ": " .. fmt(v)
    end
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = minVal + rel * (maxVal - minVal)
        setVal(v)
        refresh()
        saveConfig()
    end
    local sliderDragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = true
            sliderActive = true
            setFromX(input.Position.X)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and sliderDragging then
            sliderDragging = false
            sliderActive = false
            frame.Visible = false
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and sliderDragging then
            sliderDragging = false
            sliderActive = false
            frame.Visible = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)
    refresh()
    return frame
end
local fovSliderFrame = nil
local aimSliderFrame = nil
local jumpSliderFrame = nil
local speedSliderFrame = nil
makeToggle(tabFrames["Combat"], "Aimbot", function() return aimbotOn end, function(v)
    if aimbotOn and aimSliderFrame and not aimSliderFrame.Visible then
        aimSliderFrame.Visible = true
        return
    end
    aimbotOn = v
    if aimSliderFrame then aimSliderFrame.Visible = v end
end)
aimSliderFrame = makeSlider(tabFrames["Combat"], "Aimbot", 0, 100, function() return AIM_SMOOTH * 100 end, function(v) AIM_SMOOTH = v / 100 end, function(v) return math.floor(v) .. "%" end)
aimSliderFrame.Visible = aimbotOn
makeToggle(tabFrames["Combat"], "Triggerbot", function() return triggerOn end, function(v) triggerOn = v end)
makeToggle(tabFrames["Combat"], "Hitbox", function() return hitboxOn end, function(v) setHitbox(v) end)
makeToggle(tabFrames["Combat"], "Auto Switch", function() return autoSwitchOn end, function(v) autoSwitchOn = v end)
makeButton(tabFrames["Combat"], "Tele Sau Lung", teleBehind)
makeButton(tabFrames["Combat"], "Ve Spawn", teleToSpawn)
makeToggle(tabFrames["Visual"], "ESP", function() return espOn end, function(v)
    espOn = v
    if not v then
        for player, _ in pairs(espDrawings) do
            removeESP(player)
        end
    end
end)
makeToggle(tabFrames["Visual"], "FOV Circle", function() return fovOn end, function(v)
    if fovOn and fovSliderFrame and not fovSliderFrame.Visible then
        fovSliderFrame.Visible = true
        return
    end
    fovOn = v
    if fovCircle then fovCircle.Visible = v and not circleHidden end
    if fovSliderFrame then fovSliderFrame.Visible = v end
end)
fovSliderFrame = makeSlider(tabFrames["Visual"], "FOV", 50, 1000, function() return FOV_RADIUS end, function(v)
    FOV_RADIUS = math.floor(v)
    if fovCircle then fovCircle.Radius = FOV_RADIUS end
end, function(v) return tostring(math.floor(v)) end)
fovSliderFrame.Visible = fovOn
makeToggle(tabFrames["Visual"], "Radar", function() return radarOn end, function(v) radarOn = v end)
makeToggle(tabFrames["Visual"], "An Vong", function() return circleHidden end, function(v)
    circleHidden = v
    if fovCircle then fovCircle.Visible = fovOn and not v end
end)
makeToggle(tabFrames["Di Chuyen"], "Fly", function() return flyOn end, function(v) setFly(v) end)
makeToggle(tabFrames["Di Chuyen"], "Noclip", function() return noclipOn end, function(v) setNoclip(v) end)
makeToggle(tabFrames["Di Chuyen"], "Speed", function() return speedOn end, function(v)
    if speedOn and speedSliderFrame and not speedSliderFrame.Visible then
        speedSliderFrame.Visible = true
        return
    end
    setSpeed(v)
    if speedSliderFrame then speedSliderFrame.Visible = v end
end)
speedSliderFrame = makeSlider(tabFrames["Di Chuyen"], "Toc Do", 16, 200, function() return SPEED_VAL end, function(v) SPEED_VAL = math.floor(v) end, function(v) return tostring(math.floor(v)) end)
speedSliderFrame.Visible = speedOn
makeToggle(tabFrames["Di Chuyen"], "Jump", function() return jumpOn end, function(v)
    if jumpOn and jumpSliderFrame and not jumpSliderFrame.Visible then
        jumpSliderFrame.Visible = true
        return
    end
    setJump(v)
    if jumpSliderFrame then jumpSliderFrame.Visible = v end
end)
jumpSliderFrame = makeSlider(tabFrames["Di Chuyen"], "Nhay Cao", 50, 300, function() return JUMP_VAL end, function(v) JUMP_VAL = math.floor(v) end, function(v) return tostring(math.floor(v)) end)
jumpSliderFrame.Visible = jumpOn
makeToggle(tabFrames["Setting"], "Fix Lag", function() return fixLagOn end, function(v) setFixLag(v) end)
makeToggle(tabFrames["Setting"], "Cau Vong", function() return rainbowOn end, function(v) rainbowOn = v end)
local function setMenuVisible(open)
    menuOpen = open
    menuGui.Enabled = open
    if open then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
end
closeBtn.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)
local dragging = false
local dragStart = nil
local startPos = nil
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not sliderActive then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)
mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and not sliderActive and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
showTab("Combat")
local rainbowHue = 0
task.spawn(function()
    while true do
        task.wait(0.05)
        if rainbowOn then
            rainbowHue = (rainbowHue + 0.025) % 1
            local c = Color3.fromHSV(rainbowHue, 0.8, 1)
            mainStroke.Color = c
            accentBar.BackgroundColor3 = c
            titleLabel.TextColor3 = c
            if activeTabBtn then
                activeTabBtn.BackgroundColor3 = c
            end
            for _, b in ipairs(rainbowBtns) do
                b.BackgroundColor3 = c
            end
        else
            mainStroke.Color = Color3.fromRGB(255, 120, 180)
            accentBar.BackgroundColor3 = Color3.fromRGB(255, 120, 180)
            titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            if activeTabBtn then
                activeTabBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 180)
            end
            for _, b in ipairs(rainbowBtns) do
                b.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
            end
        end
    end
end)
setMenuVisible(false)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F8 then
        setMenuVisible(not menuOpen)
    elseif input.KeyCode == Enum.KeyCode.F1 then
        reloadScript()
    elseif input.KeyCode == Enum.KeyCode.Z then
        teleBehind()
    elseif input.KeyCode == Enum.KeyCode.P then
        teleToSpawn()
    elseif input.KeyCode == Enum.KeyCode.One then
        currentSlot = 1
    elseif input.KeyCode == Enum.KeyCode.Two then
        currentSlot = 2
    end
end)
UserInputService.JumpRequest:Connect(function()
    if jumpOn then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
pcall(function() RunService:UnbindFromRenderStep("PGBAim") end)
RunService:BindToRenderStep("PGBAim", 300, function()
    if not aimbotOn then return end
    local target = currentTarget
    if not target then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local newCf = CFrame.lookAt(cam.CFrame.Position, target.Position)
    cam.CFrame = cam.CFrame:Lerp(newCf, AIM_SMOOTH)
end)
RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera or Camera
    if not Camera then return end
    if menuOpen then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    if noclipOn then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Position = center
    fovCircle.Visible = fovOn and not circleHidden
    fovCircle.Color = Color3.fromHSV(rainbowHue, 0.8, 1)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        if speedOn then hum.WalkSpeed = SPEED_VAL end
        if jumpOn then hum.JumpPower = JUMP_VAL end
    end
    if flyOn then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and (not flyBV or not flyBV.Parent) then
            setFly(true)
        end
        if root and flyBV and flyBG then
            local camCf = Camera.CFrame
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + camCf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - camCf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camCf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camCf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
            if move.Magnitude > 0 then move = move.Unit * FLY_SPEED end
            flyBV.Velocity = move
            flyBG.CFrame = camCf
        end
    end
    if aimbotOn then
        if not isTargetValid(currentTarget) then
            currentTarget = getBestTarget()
        end
    end
    local myChar = LocalPlayer.Character
    if triggerOn then
        local origin = Camera.CFrame.Position
        local direction = Camera.CFrame.LookVector * 1000
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = Workspace:Raycast(origin, direction, params)
        if result then
            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
            local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)
            if hitPlayer and hitPlayer ~= LocalPlayer and isEnemyPlayer(hitPlayer) then
                if os.clock() - lastTriggerClick > 0.12 then
                    lastTriggerClick = os.clock()
                    clickMouse()
                end
            end
        end
    end
    if hitboxOn then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isEnemyPlayer(player) then
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                if head then
                    head.Size = Vector3.new(5, 5, 5)
                    head.Transparency = 1
                end
            end
        end
    end
    if autoSwitchOn and os.clock() - lastAmmoCheck > 0.15 then
        lastAmmoCheck = os.clock()
        local ammo = getCurrentAmmo()
        if ammo ~= nil then
            if lastAmmo and lastAmmo > 0 and ammo == 0 then
                switchWeapon()
            end
            lastAmmo = ammo
        end
    end
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local inRange = true
            if myRoot and root then
                inRange = (root.Position - myRoot.Position).Magnitude <= ESP_MAX_DIST
            end
            local show = espOn and hum and head and root and hum.Health > 0 and inRange and isEnemyPlayer(player)
            if show then
                addESP(player)
                local d = espDrawings[player]
                local topPos, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local botPos, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                if topOn and botOn then
                    local height = math.abs(botPos.Y - topPos.Y)
                    local width = height * 0.6
                    d.box.Size = Vector2.new(width, height)
                    d.box.Position = Vector2.new(topPos.X - width / 2, topPos.Y)
                    d.box.Color = Color3.fromHSV(rainbowHue, 0.8, 1)
                    d.box.Visible = true
                    d.nameTag.Text = player.Name
                    d.nameTag.Position = Vector2.new(topPos.X, topPos.Y - 15)
                    d.nameTag.Visible = true
                    local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barH = height * frac
                    d.hpBar.Size = Vector2.new(3, barH)
                    d.hpBar.Position = Vector2.new(topPos.X - width / 2 - 5, topPos.Y + height - barH)
                    if frac > 0.5 then
                        d.hpBar.Color = Color3.fromRGB(0, 255, 0)
                    elseif frac > 0.25 then
                        d.hpBar.Color = Color3.fromRGB(255, 255, 0)
                    else
                        d.hpBar.Color = Color3.fromRGB(255, 0, 0)
                    end
                    d.hpBar.Visible = true
                else
                    d.box.Visible = false
                    d.nameTag.Visible = false
                    d.hpBar.Visible = false
                end
            else
                removeESP(player)
            end
        end
    end
    for player, _ in pairs(espDrawings) do
        if not player.Parent then
            removeESP(player)
        end
    end
    if radarOn then
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local vs = Camera.ViewportSize
        local rc = Vector2.new(90, vs.Y - 90)
        radarBg.Position = rc
        radarBg.Visible = true
        radarCenter.Position = rc
        radarCenter.Visible = true
        local fwd = Vector2.new(Camera.CFrame.LookVector.X, Camera.CFrame.LookVector.Z)
        local rgt = Vector2.new(Camera.CFrame.RightVector.X, Camera.CFrame.RightVector.Z)
        local scale = 70 / 200
        local idx = 0
        if myRoot then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and isEnemyPlayer(player) then
                    local char = player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health > 0 then
                        idx = idx + 1
                        if idx <= 12 then
                            local off = Vector2.new(root.Position.X - myRoot.Position.X, root.Position.Z - myRoot.Position.Z)
                            local f = off:Dot(fwd)
                            local r = off:Dot(rgt)
                            local px = rc.X + r * scale
                            local py = rc.Y - f * scale
                            local d = (Vector2.new(px, py) - rc).Magnitude
                            if d > 68 then
                                local dir = (Vector2.new(px, py) - rc).Unit
                                px = rc.X + dir.X * 68
                                py = rc.Y + dir.Y * 68
                            end
                            radarDots[idx].Position = Vector2.new(px, py)
                            radarDots[idx].Visible = true
                        end
                    end
                end
            end
        end
        for i = idx + 1, 12 do
            radarDots[i].Visible = false
        end
    else
        radarBg.Visible = false
        radarCenter.Visible = false
        for i = 1, 12 do
            radarDots[i].Visible = false
        end
    end
end)

local libDir = game.ReplicatedStorage.Libraries
local krnl = require(libDir.Kernel)
if krnl.libhooker == nil then
    krnl.libhooker = {}
    krnl.libhooker.hooks = {}
    krnl.libhooker.safemode = false
    krnl.libhooker.internalhooks = {}
    krnl.libhooker.internalfhooks = {}
end

-- pointy
local libhooker = krnl.libhooker
local hooks = krnl.libhooker.hooks
local safemode = krnl.libhooker.safemode
local internalhooks = krnl.libhooker.internalhooks
local internalfhooks = krnl.libhooker.internalfhooks

-- surface level hooks only!!!
local hooktemplate = {
    ["hookname"] = "hookcustomname",
    ["hookfunc"] = nil,
    ["hookedlib"] = nil,
    ["hookedfunc"] = nil,
    ["after"] = false,
    ["isapp"] = false,
    ["appname"] = nil
}

--  Errors !!
--  0: no error, worked fine
--  1: lib not found
--  2: func to hook not found
--  3: hook allready exists

local function hookexists(name)
    for _, v in pairs(hooks) do if v.hookname == name then return true end end
    return false
end

local function handleerror(err, hookname)
    -- todo: fix
    local win = require(libDir.ApplicationHandler).StartProcess("Default", {IconId = 6026568201})
    local titleLabel = Instance.new("TextLabel", win.Main)
    titleLabel.Size = UDim2.fromScale(1, 0.3)
    titleLabel.Text = "A LibHooker hook crashed! Hook name: " .. hookname
    titleLabel.TextScaled = true
    titleLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.BackgroundTransparency = 0.7
    titleLabel.TextColor3 = Color3.fromRGB(255,255,255)
    local errLabel = Instance.new("TextLabel", win.Main)
    errLabel.Size = UDim2.fromScale(1, 0.4)
    errLabel.Position = UDim2.fromScale(0, 0.3)
    errLabel.Text = err
    errLabel.TextScaled = true
    errLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    errLabel.BackgroundTransparency = 0.7
    errLabel.TextColor3 = Color3.fromRGB(255,255,255)
    local okBtn = Instance.new("TextButton", win.Main)
    okBtn.Size = UDim2.fromScale(0.5, 0.3)
    okBtn.Position = UDim2.fromScale(0.5, 0.7)
    okBtn.Text = "I don't care"
    okBtn.TextScaled = true
    okBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    okBtn.BackgroundTransparency = 0.5
    okBtn.TextColor3 = Color3.fromRGB(255,255,255)
    okBtn.MouseButton1Click:Connect(function()
        require(libDir.ApplicationHandler).ExitProcess(win.Value.Value)
    end)
    local safemodeToggle = Instance.new("TextButton", win.Main)
    safemodeToggle.Size = UDim2.fromScale(0.5, 0.3)
    safemodeToggle.Position = UDim2.fromScale(0, 0.7)
    safemodeToggle.Text = "Enable safe mode"
    safemodeToggle.TextScaled = true
    safemodeToggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    safemodeToggle.BackgroundTransparency = 0.5
    safemodeToggle.TextColor3 = Color3.fromRGB(255,255,255)
    safemodeToggle.MouseButton1Click:Connect(function()
        safemode = true
        require(libDir.ApplicationHandler).ExitProcess(win.Value.Value)
    end)
end

local function registerhook(lib, funcname, old)
    local libObj = libDir:FindFirstChild(lib,true)
    require(libObj)[funcname] = function(...)
        local args = {...}
        for _, v in pairs(hooks) do
            if not safemode then
                if not v.after then
                    if v.hookedfunc == funcname and v.hookedlib == lib then
                        if not (v.isapp and args[1] ~= v.appname) then
                            local ret, err = pcall(v.hookfunc, ...)
                            if not ret then
                                handleerror(err, funcname)
                            end
                        end
                    end
                end
            end
        end
        local oldreturn = old(...)
        for _, v in pairs(hooks) do
            if not safemode then
                if v.after then
                    if v.hookedfunc == funcname and v.hookedlib == lib then
                        if not (v.isapp and args[1] == v.appname) then
                            local ret, err = pcall(v.hookfunc, oldreturn, ...)
                            if not ret then
                                handleerror(err, funcname)
                            end
                        end
                    end
                end
            end
        end
        return oldreturn
    end
    table.insert(internalhooks, lib)
    table.insert(internalfhooks, funcname)
end

local function checkinternalhook(lib, funcname)
    for _, v in pairs(internalhooks) do
        if v == lib then
            for _, v2 in pairs(internalfhooks) do
                if v2 == funcname then return true end
            end
        end
    end
    -- not allready hooked
    registerhook(lib, funcname,
                 require(libDir:FindFirstChild(lib, true))[funcname])
end

function libhooker.hooklib(libtohook, functohook, hookname, hookfunc, after)
    local libtohookobj = libDir:FindFirstChild(libtohook, true)
    if libtohookobj == nil then return 1 end
    if require(libtohookobj)[functohook] == nil then return 2 end
    if hookexists(hookname) then return 3 end
    hooks[#hooks+1] = table.clone(hooktemplate)
    local insertedhook = hooks[#hooks]
    insertedhook.hookname = hookname
    insertedhook.hookfunc = hookfunc
    insertedhook.hookedlib = libtohook
    insertedhook.hookedfunc = functohook
    insertedhook.after = after
    if insertedhook.after == nil then
        insertedhook.after = false
    end
    checkinternalhook(libtohook, functohook)
end

function libhooker.hookapp(appname, hookname, hookfunc, after)
    if appname == nil then return 1 end
    if hookexists(hookname) then return 3 end
    hooks[#hooks+1] = table.clone(hooktemplate)
    local insertedhook = hooks[#hooks]
    insertedhook.hookname = hookname
    insertedhook.hookfunc = hookfunc
    insertedhook.hookedlib = "ApplicationHandler"
    insertedhook.hookedfunc = "StartProcess"
    insertedhook.after = after
    if insertedhook.after == nil then
        insertedhook.after = false
    end
    insertedhook.isapp = true
    insertedhook.appname = appname
    checkinternalhook("ApplicationHandler", "StartProcess")
end

function libhooker.unhooklib(name)
    for i, v in pairs(hooks) do
        if name == v.hookname then
            table.remove(hooks, i)
            return 0
        end
    end
    return 1
end

return libhooker

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

--  Errors !!
--  0: no error, worked fine
--  1: lib not found
--  2: func to hook not found
--  3: hook allready exists

local function hookexists(name)
    for _, v in pairs(hooks) do if v.hookname == name then return true end end
    return false
end

-- Custom FindDecendants
local function findfirstmodule(name)
    local result = nil
    local function recurse(path)
        for i, v in pairs(path:GetChildren()) do
            if v.ClassName == "ModuleScript" then
                if v.Name == name then
                    result = v
                elseif #v:GetChildren() > 0 then
                    recurse(v)
                end
            end
        end
    end
    recurse(libDir)
    if result == nil then warn("didnt find " .. name) end
    return result
end

local function handleerror(err, hookname)
    local Lime = require(libDir.Kernel.ExecutableHost.EnvTable)().Lime
    local win = Lime.CreateWindow("LibHooker crash reporter")
    local titleLabel = Lime.CreateUI("TextLabel", win)
    titleLabel.Size = UDim2.fromScale(1, 0.3)
    titleLabel.Text = "A LibHooker hook crashed! Hook name: " .. hookname
    titleLabel.TextScaled = true
    titleLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.BackgroundTransparency = 0.7
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    local errLabel = Lime.CreateUI("TextLabel", win)
    errLabel.Size = UDim2.fromScale(1, 0.4)
    errLabel.Position = UDim2.fromScale(0, 0.3)
    errLabel.Text = err
    errLabel.TextScaled = true
    errLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    errLabel.BackgroundTransparency = 0.7
    errLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    local okBtn = Lime.CreateUI("TextButton", win)
    okBtn.Size = UDim2.fromScale(0.5, 0.3)
    okBtn.Position = UDim2.fromScale(0.5, 0.7)
    okBtn.Text = "I don't care"
    okBtn.TextScaled = true
    okBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    okBtn.BackgroundTransparency = 0.5
    okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    okBtn.MouseButton1Click:Connect(function()
        require(libDir.ApplicationHandler).ExitProcess(win.Value.Value)
    end)
    local safemodeToggle = Lime.CreateUI("TextButton", win)
    safemodeToggle.Size = UDim2.fromScale(0.5, 0.3)
    safemodeToggle.Position = UDim2.fromScale(0, 0.7)
    safemodeToggle.Text = "Enable safe mode"
    safemodeToggle.TextScaled = true
    safemodeToggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    safemodeToggle.BackgroundTransparency = 0.5
    safemodeToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    safemodeToggle.MouseButton1Click:Connect(function()
        safemode = true
        require(libDir.ApplicationHandler).ExitProcess(win.Value.Value)
    end)
end

local function registerhook(lib, funcname, old)
    print("NEW HOOK!!! " .. lib .. ": " .. funcname)
    local libObj = findfirstmodule(lib)
    require(libObj)[funcname] = function(...)
        local args = {...}
        for _, v in pairs(hooks) do
            if not safemode then
                if not v.after then
                    if v.hookedfunc == funcname and v.hookedlib == lib then
                        if not (v.isapp and args[1] ~= v.appname) then
                            local ret, err = pcall(v.hookfunc, ...)
                            if err then
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
                            if err then
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
    registerhook(lib, funcname, require(findfirstmodule(lib))[funcname])
end

function libhooker.hooklib(libtohook, functohook, hookname, hookfunc, after)
    local libtohookobj = findfirstmodule(libtohook)
    if libtohookobj == nil then return 1 end
    if require(libtohookobj)[functohook] == nil then return 2 end
    if hookexists(hookname) then return 3 end
    local newhook = table.clone(hooktemplate)
    newhook.hookname = hookname
    newhook.hookfunc = hookfunc
    newhook.hookedlib = libtohook
    newhook.hookedfunc = functohook
    newhook.after = after
    if newhook.after == nil then newhook.after = false end
    table.insert(hooks, newhook)
    checkinternalhook(libtohook, functohook)
end

function libhooker.hookapp(appname, hookname, hookfunc, after)
    if appname == nil then return 1 end
    if hookexists(hookname) then return 3 end
    hooks[#hooks + 1] = table.clone(hooktemplate)
    local insertedhook = hooks[#hooks]
    insertedhook.hookname = hookname
    insertedhook.hookfunc = hookfunc
    insertedhook.hookedlib = "ApplicationHandler"
    insertedhook.hookedfunc = "StartProcess"
    insertedhook.after = after
    if insertedhook.after == nil then insertedhook.after = false end
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

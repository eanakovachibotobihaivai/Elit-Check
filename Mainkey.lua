--[[
    WANG CHI KEY SYSTEM - CONFIG LOADER
    Loads config from external file
    Security: Core logic is here, config is separate
--]]

-- ========== CONFIGURATION URL ==========
-- !!! CHANGE THIS TO YOUR RAW CONFIG URL !!!
local CONFIG_URL = "https://raw.githubusercontent.com/eanakovachibotobihaivai/Elit-Check/refs/heads/main/check.lua"

-- ========== LOAD CONFIGURATION ==========
local config = nil
local loadSuccess, loadError = pcall(function()
    local configContent = game:HttpGet(CONFIG_URL)
    config = loadstring(configContent)()
end)

if not loadSuccess or not config then
    error("Failed to load configuration: " .. tostring(loadError))
    return
end

-- ========== PERSISTENCE CHECK ==========
local function isSessionActive()
    if shared and shared[config.session.sessionKey] == true then
        return true
    end
    if _G[config.session.sessionKey] == true then
        return true
    end
    return false
end

local function markSessionActive()
    if shared then
        shared[config.session.sessionKey] = true
    end
    _G[config.session.sessionKey] = true
end

if isSessionActive() then
    pcall(function()
        loadstring(game:HttpGet(config.hub.url))()
    end)
    return
end

-- ========== JSON LIBRARY ==========
local function encodeJSON(t)
    local function serialize(val)
        local typ = type(val)
        if typ == "nil" then return "null"
        elseif typ == "boolean" then return val and "true" or "false"
        elseif typ == "number" then return tostring(val)
        elseif typ == "string" then return '"' .. val:gsub('["\\]', '\\%0') .. '"'
        elseif typ == "table" then
            local isArray = true
            for k in pairs(val) do
                if type(k) ~= "number" then
                    isArray = false
                    break
                end
            end
            local items = {}
            if isArray then
                for i, v in ipairs(val) do
                    table.insert(items, serialize(v))
                end
                return "[" .. table.concat(items, ",") .. "]"
            else
                for k, v in pairs(val) do
                    table.insert(items, serialize(k) .. ":" .. serialize(v))
                end
                return "{" .. table.concat(items, ",") .. "}"
            end
        else return '""'
        end
    end
    return serialize(t)
end

local function decodeJSON(str)
    local function parseValue(pos)
        while true do
            local ch = str:sub(pos, pos)
            if ch == " " or ch == "\n" or ch == "\r" or ch == "\t" then
                pos = pos + 1
            else
                break
            end
        end
        local ch = str:sub(pos, pos)
        if ch == '"' then
            local start = pos + 1
            local esc = false
            for i = start, #str do
                local c = str:sub(i, i)
                if not esc then
                    if c == '\\' then
                        esc = true
                    elseif c == '"' then
                        return str:sub(start, i - 1), i + 1
                    end
                else
                    esc = false
                end
            end
            error("Unterminated string")
        elseif ch == "{" then
            local obj = {}
            pos = pos + 1
            while true do
                while true do
                    local nch = str:sub(pos, pos)
                    if nch == " " or nch == "\n" or nch == "\r" or nch == "\t" then
                        pos = pos + 1
                    else
                        break
                    end
                end
                if str:sub(pos, pos) == "}" then
                    return obj, pos + 1
                end
                local key, newPos = parseValue(pos)
                pos = newPos
                while true do
                    local nch = str:sub(pos, pos)
                    if nch == " " or nch == "\n" or nch == "\r" or nch == "\t" then
                        pos = pos + 1
                    else
                        break
                    end
                end
                if str:sub(pos, pos) ~= ":" then
                    error("Expected ':'")
                end
                pos = pos + 1
                local value, newPos2 = parseValue(pos)
                pos = newPos2
                obj[key] = value
                while true do
                    local nch = str:sub(pos, pos)
                    if nch == " " or nch == "\n" or nch == "\r" or nch == "\t" then
                        pos = pos + 1
                    else
                        break
                    end
                end
                if str:sub(pos, pos) == "}" then
                    return obj, pos + 1
                elseif str:sub(pos, pos) == "," then
                    pos = pos + 1
                else
                    error("Expected ',' or '}'")
                end
            end
        elseif ch == "[" then
            local arr = {}
            pos = pos + 1
            local idx = 1
            while true do
                while true do
                    local nch = str:sub(pos, pos)
                    if nch == " " or nch == "\n" or nch == "\r" or nch == "\t" then
                        pos = pos + 1
                    else
                        break
                    end
                end
                if str:sub(pos, pos) == "]" then
                    return arr, pos + 1
                end
                local value, newPos = parseValue(pos)
                pos = newPos
                arr[idx] = value
                idx = idx + 1
                while true do
                    local nch = str:sub(pos, pos)
                    if nch == " " or nch == "\n" or nch == "\r" or nch == "\t" then
                        pos = pos + 1
                    else
                        break
                    end
                end
                if str:sub(pos, pos) == "]" then
                    return arr, pos + 1
                elseif str:sub(pos, pos) == "," then
                    pos = pos + 1
                else
                    error("Expected ',' or ']'")
                end
            end
        elseif ch == "t" and str:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        elseif ch == "f" and str:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        elseif ch == "n" and str:sub(pos, pos + 3) == "null" then
            return nil, pos + 4
        elseif (ch >= "0" and ch <= "9") or ch == "-" then
            local start = pos
            if ch == "-" then pos = pos + 1 end
            while true do
                local dch = str:sub(pos, pos)
                if (dch >= "0" and dch <= "9") or dch == "." or dch == "e" or dch == "E" or dch == "+" or dch == "-" then
                    pos = pos + 1
                else
                    break
                end
            end
            local numStr = str:sub(start, pos - 1)
            return tonumber(numStr), pos
        else
            error("Unexpected character: " .. ch)
        end
    end
    local result, newPos = parseValue(1)
    return result
end

-- ========== STORAGE FUNCTIONS ==========
local KEY_FILE = config.storage.folderName .. "/" .. config.storage.fileName

local function createFolder()
    local makeFolderExists, makeFolderFunc = pcall(function() return makefolder end)
    if makeFolderExists then
        pcall(function() makeFolderFunc(config.storage.folderName) end)
    end
end

local function saveKeyToJSON(key, status)
    createFolder()
    local writefileExists, writefileFunc = pcall(function() return writefile end)
    if writefileExists then
        local data = {key = key or "", verified = status or false, last_verified = os.time()}
        pcall(function() writefileFunc(KEY_FILE, encodeJSON(data)) end)
        return true
    end
    return false
end

local function loadKeyFromJSON()
    local readfileExists, readfileFunc = pcall(function() return readfile end)
    if readfileExists then
        local success, content = pcall(function() return readfileFunc(KEY_FILE) end)
        if success and content and content ~= "" then
            local data = decodeJSON(content)
            if data and data.key then return data.key, data.verified end
        end
    end
    return nil, false
end

-- ========== PLATOBOOST LIBRARY ==========
local a=2^32;local b=a-1;local function c(d,e)local f,g=0,1;while d~=0 or e~=0 do local h,i=d%2,e%2;local j=(h+i)%2;f=f+j*g;d=math.floor(d/2)e=math.floor(e/2)g=g*2 end;return f%a end;local function k(d,e,l,...)local m;if e then d=d%a;e=e%a;m=c(d,e)if l then m=k(m,l,...)end;return m elseif d then return d%a else return 0 end end;local function n(d,e,l,...)local m;if e then d=d%a;e=e%a;m=(d+e-c(d,e))/2;if l then m=n(m,l,...)end;return m elseif d then return d%a else return b end end;local function o(p)return b-p end;local function q(d,r)if r<0 then return lshift(d,-r)end;return math.floor(d%2^32/2^r)end;local function s(p,r)if r>31 or r<-31 then return 0 end;return q(p%a,r)end;local function lshift(d,r)if r<0 then return s(d,-r)end;return d*2^r%2^32 end;local function t(p,r)p=p%a;r=r%32;local u=n(p,2^r-1)return s(p,r)+lshift(u,32-r)end;local v={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}local function w(x)return string.gsub(x,".",function(l)return string.format("%02x",string.byte(l))end)end;local function y(z,A)local x=""for B=1,A do local C=z%256;x=string.char(C)..x;z=(z-C)/256 end;return x end;local function D(x,B)local A=0;for B=B,B+3 do A=A*256+string.byte(x,B)end;return A end;local function E(F,G)local H=64-(G+9)%64;G=y(8*G,8)F=F.."\128"..string.rep("\0",H)..G;assert(#F%64==0)return F end;local function I(J)J[1]=0x6a09e667;J[2]=0xbb67ae85;J[3]=0x3c6ef372;J[4]=0xa54ff53a;J[5]=0x510e527f;J[6]=0x9b05688c;J[7]=0x1f83d9ab;J[8]=0x5be0cd19;return J end;local function K(F,B,J)local L={}for M=1,16 do L[M]=D(F,B+(M-1)*4)end;for M=17,64 do local N=L[M-15]local O=k(t(N,7),t(N,18),s(N,3))N=L[M-2]L[M]=(L[M-16]+O+L[M-7]+k(t(N,17),t(N,19),s(N,10)))%a end;local d,e,l,P,Q,R,S,T=J[1],J[2],J[3],J[4],J[5],J[6],J[7],J[8]for B=1,64 do local O=k(t(d,2),t(d,13),t(d,22))local U=k(n(d,e),n(d,l),n(e,l))local V=(O+U)%a;local W=k(t(Q,6),t(Q,11),t(Q,25))local X=k(n(Q,R),n(o(Q),S))local Y=(T+W+X+v[B]+L[B])%a;T=S;S=R;R=Q;Q=(P+Y)%a;P=l;l=e;e=d;d=(Y+V)%a end;J[1]=(J[1]+d)%a;J[2]=(J[2]+e)%a;J[3]=(J[3]+l)%a;J[4]=(J[4]+P)%a;J[5]=(J[5]+Q)%a;J[6]=(J[6]+R)%a;J[7]=(J[7]+S)%a;J[8]=(J[8]+T)%a end;local function Z(F)F=E(F,#F)local J=I({})for B=1,#F,64 do K(F,B,J)end;return w(y(J[1],4)..y(J[2],4)..y(J[3],4)..y(J[4],4)..y(J[5],4)..y(J[6],4)..y(J[7],4)..y(J[8],4))end;local e;local l={["\\"]="\\",["\""]="\"",["\b"]="b",["\f"]="f",["\n"]="n",["\r"]="r",["\t"]="t"}local P={["/"]="/"}for Q,R in pairs(l)do P[R]=Q end;local S=function(T)return"\\"..(l[T]or string.format("u%04x",T:byte()))end;local B=function(M)return"null"end;local v=function(M,z)local _={}z=z or{}if z[M]then error("circular reference")end;z[M]=true;if rawget(M,1)~=nil or next(M)==nil then local A=0;for Q in pairs(M)do if type(Q)~="number"then error("invalid table: mixed or invalid key types")end;A=A+1 end;if A~=#M then error("invalid table: sparse array")end;for a0,R in ipairs(M)do table.insert(_,e(R,z))end;z[M]=nil;return"["..table.concat(_,",").."]"else for Q,R in pairs(M)do if type(Q)~="string"then error("invalid table: mixed or invalid key types")end;table.insert(_,e(Q,z)..":"..e(R,z))end;z[M]=nil;return"{"..table.concat(_,",").."}"end end;local g=function(M)return'"'..M:gsub('[%z\1-\31\\"]',S)..'"'end;local a1=function(M)if M~=M or M<=-math.huge or M>=math.huge then error("unexpected number value '"..tostring(M).."'")end;return string.format("%.14g",M)end;local j={["nil"]=B,["table"]=v,["string"]=g,["number"]=a1,["boolean"]=tostring}e=function(M,z)local x=type(M)local a2=j[x]if a2 then return a2(M,z)end;error("unexpected type '"..x.."'")end;local a3=function(M)return e(M)end;local a4;local N=function(...)local _={}for a0=1,select("#",...)do _[select(a0,...)]=true end;return _ end;local L=N(" ","\t","\r","\n")local p=N(" ","\t","\r","\n","]","}",",")local a5=N("\\","/",'"',"b","f","n","r","t","u")local m=N("true","false","null")local a6={["true"]=true,["false"]=false,["null"]=nil}local a7=function(a8,a9,aa,ab)for a0=a9,#a8 do if aa[a8:sub(a0,a0)]~=ab then return a0 end end;return#a8+1 end;local ac=function(a8,a9,J)local ad=1;local ae=1;for a0=1,a9-1 do ae=ae+1;if a8:sub(a0,a0)=="\n"then ad=ad+1;ae=1 end end;error(string.format("%s at line %d col %d",J,ad,ae))end;local af=function(A)local a2=math.floor;if A<=0x7f then return string.char(A)elseif A<=0x7ff then return string.char(a2(A/64)+192,A%64+128)elseif A<=0xffff then return string.char(a2(A/4096)+224,a2(A%4096/64)+128,A%64+128)elseif A<=0x10ffff then return string.char(a2(A/262144)+240,a2(A%262144/4096)+128,a2(A%4096/64)+128,A%64+128)end;error(string.format("invalid unicode codepoint '%x'",A))end;local ag=function(ah)local ai=tonumber(ah:sub(1,4),16)local aj=tonumber(ah:sub(7,10),16)if aj then return af((ai-0xd800)*0x400+aj-0xdc00+0x10000)else return af(ai)end end;local ak=function(a8,a0)local _=""local al=a0+1;local Q=al;while al<=#a8 do local am=a8:byte(al)if am<32 then ac(a8,al,"control character in string")elseif am==92 then _=_..a8:sub(Q,al-1)al=al+1;local T=a8:sub(al,al)if T=="u"then local an=a8:match("^[dD][89aAbB]%x%x\\u%x%x%x%x",al+1)or a8:match("^%x%x%x%x",al+1)or ac(a8,al-1,"invalid unicode escape in string")_=_..ag(an)al=al+#an else if not a5[T]then ac(a8,al-1,"invalid escape char '"..T.."' in string")end;_=_..P[T]end;Q=al+1 elseif am==34 then _=_..a8:sub(Q,al-1)return _,al+1 end;al=al+1 end;ac(a8,a0,"expected closing quote for string")end;local ao=function(a8,a0)local am=a7(a8,a0,p)local ah=a8:sub(a0,am-1)local A=tonumber(ah)if not A then ac(a8,a0,"invalid number '"..ah.."'")end;return A,am end;local ap=function(a8,a0)local am=a7(a8,a0,p)local aq=a8:sub(a0,am-1)if not m[aq]then ac(a8,a0,"invalid literal '"..aq.."'")end;return a6[aq],am end;local ar=function(a8,a0)local _={}local A=1;a0=a0+1;while 1 do local am;a0=a7(a8,a0,L,true)if a8:sub(a0,a0)=="]"then a0=a0+1;break end;am,a0=a4(a8,a0)_[A]=am;A=A+1;a0=a7(a8,a0,L,true)local as=a8:sub(a0,a0)a0=a0+1;if as=="]"then break end;if as~=","then ac(a8,a0,"expected ']' or ','")end end;return _,a0 end;local at=function(a8,a0)local _={}a0=a0+1;while 1 do local au,M;a0=a7(a8,a0,L,true)if a8:sub(a0,a0)=="}"then a0=a0+1;break end;if a8:sub(a0,a0)~='"'then ac(a8,a0,"expected string for key")end;au,a0=a4(a8,a0)a0=a7(a8,a0,L,true)if a8:sub(a0,a0)~=":"then ac(a8,a0,"expected ':' after key")end;a0=a7(a8,a0+1,L,true)M,a0=a4(a8,a0)_[au]=M;a0=a7(a8,a0,L,true)local as=a8:sub(a0,a0)a0=a0+1;if as=="}"then break end;if as~=","then ac(a8,a0,"expected '}' or ','")end end;return _,a0 end;local av={['"']=ak,["0"]=ao,["1"]=ao,["2"]=ao,["3"]=ao,["4"]=ao,["5"]=ao,["6"]=ao,["7"]=ao,["8"]=ao,["9"]=ao,["-"]=ao,["t"]=ap,["f"]=ap,["n"]=ap,["["]=ar,["{"]=at}a4=function(a8,a9)local as=a8:sub(a9,a9)local a2=av[as]if a2 then return a2(a8,a9)end;ac(a8,a9,"unexpected character '"..as.."'")end;local aw=function(a8)if type(a8)~="string"then error("expected argument of type string, got "..type(a8))end;local _,a9=a4(a8,a7(a8,1,L,true))a9=a7(a8,a9,L,true)if a9<=#a8 then ac(a8,a9,"trailing garbage")end;return _ end;
local lEncode, lDecode, lDigest = a3, aw, Z;

-- ========== PLATOBOOST API FUNCTIONS ==========
local requestSending = false
local fSetClipboard, fRequest, fStringChar, fToString, fStringSub, fOsTime, fMathRandom, fMathFloor, fGetHwid = 
    setclipboard or toclipboard, 
    request or http_request or syn.request or function() end, 
    string.char, tostring, string.sub, os.time, math.random, math.floor, 
    gethwid or function() return game:GetService("Players").LocalPlayer.UserId end

local cachedLink, cachedTime = "", 0
local host = config.connection.hosts[1]
local isAPILoaded = false

local function findFastestHost()
    local results = {}
    for _, h in ipairs(config.connection.hosts) do
        task.spawn(function()
            local startTime = os.clock()
            local success, res = pcall(function()
                return fRequest({Url = h .. "/public/connectivity", Method = "GET", Timeout = 3})
            end)
            local latency = (os.clock() - startTime) * 1000
            if success and res and (res.StatusCode == 200 or res.StatusCode == 429) then
                table.insert(results, {host = h, latency = latency})
            end
        end)
    end
    task.wait(2)
    if #results > 0 then
        table.sort(results, function(a, b) return a.latency < b.latency end)
        return results[1].host
    end
    return config.connection.hosts[1]
end

local function warmUpConnection()
    pcall(function()
        return fRequest({Url = host .. "/public/connectivity", Method = "GET", Headers = {["Connection"] = "keep-alive"}})
    end)
end

local function fastCacheLink()
    if cachedTime + config.connection.cacheDuration < fOsTime() then
        local success, response = pcall(function()
            return fRequest({
                Url = host .. "/public/start",
                Method = "POST",
                Body = lEncode({service = config.platoboost.service, identifier = lDigest(fGetHwid())}),
                Headers = {["Content-Type"] = "application/json", ["Connection"] = "keep-alive"}
            })
        end)
        if success and response and response.StatusCode == 200 then
            local decoded = lDecode(response.Body)
            if decoded.success == true then
                cachedLink = decoded.data.url
                cachedTime = fOsTime()
                return true, cachedLink
            end
        end
        return false, "Connection failed"
    end
    return true, cachedLink
end

task.spawn(function()
    host = findFastestHost()
    warmUpConnection()
    fastCacheLink()
    isAPILoaded = true
end)

local maxWaitTime = config.connection.maxWaitTime
local startWait = os.time()
while not isAPILoaded and (os.time() - startWait) < maxWaitTime do
    task.wait(0.1)
end

-- ========== CREATE UI ==========
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

local function generateNonce()
    local str = ""
    for _ = 1, 16 do
        str = str .. fStringChar(fMathFloor(fMathRandom() * (122 - 97 + 1)) + 97)
    end
    return str
end

local function copyLink()
    local success, link = fastCacheLink()
    if success and link then
        fSetClipboard(link)
        updateStatus("✅ Link copied! Open browser to complete task.", Color3.fromRGB(120, 255, 120), Color3.fromRGB(80, 255, 80))
        return true
    end
    updateStatus("❌ Failed to get link", Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 80, 80))
    return false
end

local function verifyKey(key)
    if requestSending then
        updateStatus("⏳ Request in progress...", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 80))
        return false
    end
    requestSending = true
    local nonce = generateNonce()
    local endpoint = host .. "/public/whitelist/" .. fToString(config.platoboost.service) .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key
    if config.platoboost.useNonce then endpoint = endpoint .. "&nonce=" .. nonce end
    local success, response = pcall(function()
        return fRequest({Url = endpoint, Method = "GET"})
    end)
    requestSending = false
    if success and response and response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success and decoded.data.valid == true then
            if config.platoboost.useNonce then
                if decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. config.platoboost.secret) then
                    return true
                end
            else
                return true
            end
        end
    end
    return false
end

-- ========== UI CREATION ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WangChiKeySystem"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, config.ui.width, 0, config.ui.height)
mainFrame.Position = UDim2.new(0.5, -(config.ui.width/2), 0.5, -(config.ui.height/2))
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 18, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 40))
})
gradient.Rotation = 45
gradient.Parent = mainFrame

local titleBg = Instance.new("Frame")
titleBg.Size = UDim2.new(1, 0, 0, 65)
titleBg.Position = UDim2.new(0, 0, 0, 0)
titleBg.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
titleBg.BackgroundTransparency = 0.5
titleBg.BorderSizePixel = 0
titleBg.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 16)
titleCorner.Parent = titleBg

local icon = Instance.new("TextLabel")
icon.Size = UDim2.new(0, 30, 0, 30)
icon.Position = UDim2.new(0, 15, 0, 18)
icon.BackgroundTransparency = 1
icon.Text = "🔑"
icon.TextColor3 = Color3.fromRGB(255, 200, 80)
icon.TextSize = 24
icon.Font = Enum.Font.GothamBold
icon.Parent = titleBg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 35)
title.Position = UDim2.new(0, 50, 0, 10)
title.BackgroundTransparency = 1
title.Text = config.ui.title
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBg

local line = Instance.new("Frame")
line.Size = UDim2.new(0.9, 0, 0, 1)
line.Position = UDim2.new(0.05, 0, 0, 65)
line.BackgroundColor3 = Color3.fromRGB(config.ui.accentColor.r, config.ui.accentColor.g, config.ui.accentColor.b)
line.BackgroundTransparency = 0.6
line.BorderSizePixel = 0
line.Parent = mainFrame

local inputLabel = Instance.new("TextLabel")
inputLabel.Size = UDim2.new(0.8, 0, 0, 20)
inputLabel.Position = UDim2.new(0.1, 0, 0.3, 0)
inputLabel.BackgroundTransparency = 1
inputLabel.Text = "🔐 ENTER YOUR KEY"
inputLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
inputLabel.TextSize = 11
inputLabel.Font = Enum.Font.GothamBold
inputLabel.TextXAlignment = Enum.TextXAlignment.Left
inputLabel.Parent = mainFrame

local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(0.8, 0, 0, 45)
keyBox.Position = UDim2.new(0.1, 0, 0.38, 0)
keyBox.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBox.PlaceholderText = "Paste your key here..."
keyBox.Text = ""
keyBox.Font = Enum.Font.Gotham
keyBox.TextSize = 13
keyBox.BorderSizePixel = 0
keyBox.ClipsDescendants = true
keyBox.Parent = mainFrame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 10)
boxCorner.Parent = keyBox

local getKeyBtn = Instance.new("TextButton")
getKeyBtn.Size = UDim2.new(0.38, 0, 0, 45)
getKeyBtn.Position = UDim2.new(0.08, 0, 0.58, 0)
getKeyBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
getKeyBtn.Text = "GET KEY"
getKeyBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
getKeyBtn.TextSize = 12
getKeyBtn.Font = Enum.Font.GothamBold
getKeyBtn.BorderSizePixel = 0
getKeyBtn.Parent = mainFrame

local getKeyCorner = Instance.new("UICorner")
getKeyCorner.CornerRadius = UDim.new(0, 8)
getKeyCorner.Parent = getKeyBtn

local verifyBtn = Instance.new("TextButton")
verifyBtn.Size = UDim2.new(0.38, 0, 0, 45)
verifyBtn.Position = UDim2.new(0.54, 0, 0.58, 0)
verifyBtn.BackgroundColor3 = Color3.fromRGB(config.ui.accentColor.r, config.ui.accentColor.g, config.ui.accentColor.b)
verifyBtn.Text = "VERIFY ✓"
verifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
verifyBtn.TextSize = 12
verifyBtn.Font = Enum.Font.GothamBold
verifyBtn.BorderSizePixel = 0
verifyBtn.Parent = mainFrame

local verifyCorner = Instance.new("UICorner")
verifyCorner.CornerRadius = UDim.new(0, 8)
verifyCorner.Parent = verifyBtn

local verifyGradient = Instance.new("UIGradient")
verifyGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(config.ui.accentColor.r, config.ui.accentColor.g, config.ui.accentColor.b)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 80, 220))
})
verifyGradient.Rotation = 90
verifyGradient.Parent = verifyBtn

local statusBg = Instance.new("Frame")
statusBg.Size = UDim2.new(0.85, 0, 0, 50)
statusBg.Position = UDim2.new(0.075, 0, 0.78, 0)
statusBg.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
statusBg.BackgroundTransparency = 0.6
statusBg.BorderSizePixel = 0
statusBg.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusBg

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 1, 0)
statusLabel.Position = UDim2.new(0, 5, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "⚡ Ready | Enter your key to continue"
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
statusLabel.TextSize = 10
statusLabel.TextWrapped = true
statusLabel.Parent = statusBg

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 6, 0, 6)
statusDot.Position = UDim2.new(0, 8, 0, 22)
statusDot.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
statusDot.BorderSizePixel = 0
statusDot.Parent = statusBg

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local function updateStatus(msg, color, dotColor)
    statusLabel.Text = msg
    statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    if dotColor then
        local tween = TweenService:Create(statusDot, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundColor3 = dotColor})
        tween:Play()
    end
end

local function animateClick(button)
    local originalSize = button.Size
    local tween1 = TweenService:Create(button, TweenInfo.new(0.08), {Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.95, originalSize.Y.Scale, originalSize.Y.Offset * 0.95)})
    local tween2 = TweenService:Create(button, TweenInfo.new(0.08), {Size = originalSize})
    tween1:Play()
    tween1.Completed:Connect(function() tween2:Play() end)
end

local function loadHubScript()
    updateStatus("📥 Loading Wang Chi Hub...", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 100))
    local success, result = pcall(function()
        return loadstring(game:HttpGet(config.hub.url))()
    end)
    if success then
        updateStatus("✅ Welcome to Wang Chi Hub!", Color3.fromRGB(120, 255, 120), Color3.fromRGB(80, 255, 80))
        markSessionActive()
        saveKeyToJSON(keyBox.Text, true)
        wait(1.5)
        screenGui:Destroy()
    else
        updateStatus("❌ Load failed: " .. tostring(result):sub(1, 30), Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 80, 80))
    end
end

local function autoVerifySavedKey()
    local savedKey, wasVerified = loadKeyFromJSON()
    if savedKey and savedKey ~= "" then
        keyBox.Text = savedKey
        updateStatus("🔍 Auto-verifying saved key...", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 80))
        local success = verifyKey(savedKey)
        if success then
            updateStatus("✅ Key verified! Loading hub...", Color3.fromRGB(120, 255, 120), Color3.fromRGB(80, 255, 80))
            loadHubScript()
            return true
        else
            updateStatus("⚠️ Saved key invalid! Please get a new key.", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 80))
            saveKeyToJSON(savedKey, false)
            return false
        end
    end
    return false
end

local autoVerified = autoVerifySavedKey()
if autoVerified then
    return
end

getKeyBtn.MouseButton1Click:Connect(function()
    animateClick(getKeyBtn)
    updateStatus("📋 Generating link...", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 80))
    copyLink()
end)

verifyBtn.MouseButton1Click:Connect(function()
    animateClick(verifyBtn)
    local userKey = keyBox.Text
    if userKey == "" then
        updateStatus("⚠️ Please get a key first!", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 80))
        return
    end
    updateStatus("🔍 Verifying key...", Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 200, 80))
    local success = verifyKey(userKey)
    if success then
        saveKeyToJSON(userKey, true)
        updateStatus("✅ Key verified! Loading hub...", Color3.fromRGB(120, 255, 120), Color3.fromRGB(80, 255, 80))
        loadHubScript()
    else
        updateStatus("❌ Invalid key! Click GET KEY to get a valid one.", Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 80, 80))
        local originalPos = keyBox.Position
        for i = 1, 4 do
            local shakeTween = TweenService:Create(keyBox, TweenInfo.new(0.03), {Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset + (i % 2 == 0 and 3 or -3), originalPos.Y.Scale, originalPos.Y.Offset)})
            shakeTween:Play()
            task.wait(0.03)
        end
        local resetTween = TweenService:Create(keyBox, TweenInfo.new(0.05), {Position = originalPos})
        resetTween:Play()
    end
end)

task.wait(0.1)
keyBox:CaptureFocus()

print("✅ Wang Chi Key System Loaded (Config from external file)")
print("📁 Config URL: " .. CONFIG_URL)
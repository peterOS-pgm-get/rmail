local Logger = pos.require('logger')
local log = Logger('/home/.pgmLog/rmailServer.log')
log:info('Staritng rMail Server')

local hostname = "rmail"
local dirPath = "/home/rmailServer/"
local cfgPath = "/home/.appdata/rmailServer/server.cfg"
local supportOld = false
if fs.exists(cfgPath) then
    local f = fs.open(cfgPath, "r")
    if f then
        local cfg = textutils.unserialiseJSON(f.readAll())
        f.close()
        hostname = cfg.hostname or hostname
        dirPath = cfg.dirPath or dirPath
        supportOld = cfg.supportOld or supportOld
    else
        log:error('Could not read config file')
    end
end

local modem = {}
modem.transmit = function(ps, pr, m) end
modem.close = function(_port) end
modem.open = function(_port) end
local id = os.getComputerID()
local port = 10025
local function setup()
    net.setup()
    net.open(net.standardPorts.rmail)
    if supportOld then
        if modem then return true end
        local modems = { peripheral.find("modem", function(name, mdm)
            return mdm.isWireless()
        end) }
        if #modems == 0 then
            error("No Modem Attached", 0)
            return false
        end
        modem = modems[1]
        if not modem then
            error("No Modem Attached", 0)
            return false
        end
        modem.open(port)
    end
    return true
end
local function close()
    if modem then modem.close(port) end
    modem = nil
end

-- local function strSplit (inputstr, sep)
--     if sep == nil then
--         sep = "%s"
--     end
--     local t={}
--     for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
--         table.insert(t, str)
--     end
--     return t
-- end

print("Rmail Server started with hostname '"..hostname.."'")

local userPath = dirPath.."users.json"
local users = {}
if fs.exists(userPath) then
    local f = fs.open(userPath, "r")
    if f then
        users = textutils.unserialiseJSON(f.readAll())
        f.close()
        if users == nil then
            log:error('User table corrupted')
            error("User table at '"..userPath.."' was malformed", 0)
            return
        end
        print("Loaded users")
    else
        log:error('Could not read user table')
    end
else
    local f = fs.open(userPath, "w")
    local tbl = {
        ["username"]={
            username="username",
            password = "password",
            mail = {}
        }
    }
    if f then
        f.write(textutils.serialiseJSON(tbl))
        f.close()
    else
        log:error('Could not write to '..userPath)
    end
    error("No user table at '"..userPath.."', making a default one", 0)
    return
end

local mailPath = dirPath.."mail.json"
local rmail = {cUUID=0}
if fs.exists(mailPath) then
    local f = fs.open(mailPath, "r")
    if f then
        rmail = textutils.unserialiseJSON(f.readAll())
        f.close()
        if users == nil then
            error("Mail table at '"..mailPath.."' was malformed", 0)
            return
        end
        print("Loaded mail")
    else
        log:error('Could not write mail table')
    end
end

local function respondFail(dest, rsp, desc, meta)
    meta = meta or {}
    if desc == nil then
        desc = ""
    end

    local msg = {
        type="rmail",
        origin=id,
        server=hostname,
        host=dest,
        rsp={
            cmpt=false,
            type=rsp,
            text=desc
        },
        meta=meta
    }
    modem.transmit(port, port, msg)
end
local function respondSent(dest, uuid, meta)
    meta = meta or {}

    local msg = {
        type="rmail",
        origin=id,
        server=hostname,
        host=dest,
        rsp={
            cmpt=true,
            type="SENT"
        },
        mailUUID=uuid,
        meta=meta
    }
    modem.transmit(port, port, msg)
end
local function respondMail(dest, mail, meta)
    meta = meta or {}

    local msg = {
        type="rmail",
        origin=id,
        server=hostname,
        host=dest,
        rsp={
            cmpt=true,
            type="MAIL",
        },
        mail=mail,
        meta=meta
    }
    modem.transmit(port, port, msg)
end
local function respondList(dest, list, meta)
    meta = meta or {}

    local msg = {
        type="rmail",
        origin=id,
        server=hostname,
        host=dest,
        rsp={
            cmpt=true,
            type="LIST",
        },
        list=list,
        meta=meta
    }
    modem.transmit(port, port, msg)
end

local function authUser(user)
    if users[user.name] == nil then
        return nil
    end
    if users[user.name].password == user.pass then
        return users[user.name]
    end
    return nil
end

local function save()
    local uF = fs.open(userPath, "w")
    if uF then
        uF.write(textutils.serialiseJSON(users))
        uF.close()
    else
        log:error('Could not write to '..userPath)
    end

    local mF = fs.open(mailPath, "w")
    if mF then
        mF.write(textutils.serialiseJSON(rmail))
        mF.close()
    else
        log:error('Could not write to '..mailPath)
    end
end

local function prossessCommand(command)
    local args = strSplit(command, " ")
    if #args == 0 then
        return true
    end
    if args[1] == "stop" then
        return false
    elseif args[1] == "listUsers" then
        for name,_ in pairs(users) do
            print(name)
        end
    elseif args[1] == "addUser" then
        if #args ~= 3 then
            print("Must have username and password")
            return true
        end
        local user = {
            username = args[2],
            password = args[3],
            mail = {}
        }
        if users[user.username] ~= nil then
            print("User Already exists")
            return true
        end
        users[user.username] = user
        save()
        print("User "..args[2].." added")
    elseif args[1] == "help" then
        print("Avalible Commands: stop, listUsers, addUser")
    end
    return true
end

local cmd = ""

local function drawCmd()
    term.clearLine()
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y)
    term.setTextColor(colors.orange)
    term.write(">")
    term.setTextColor(colors.white)
    term.write(" "..cmd)
    term.setCursorBlink(true)
end

local function loop()
    local event = { os.pullEventRaw() }
    if event[1] == "modem_message" then
        local eName, side, channel, replyChannel, message, distance = unpack(event)
        if channel == port then
            if message.type == nil then
                return true
            end
            if message.type == "rmail" then
                if message.host == hostname then
                    if message.user == nil then
                        respondFail(message.origin, "MALFORMED_REQUEST", "Missing user object")
                        return true
                    end
                    if message.method == nil then
                        respondFail(message.origin, "MALFORMED_REQUEST", "Missing method")
                        return true
                    end

                    local user = authUser(message.user)
                    if user == nil then
                        respondFail(message.origin, "INVALID_CREDENTIALS")
                        return true
                    end
                    if user.mail == nil then
                        user.mail = {}
                    end

                    if message.method == "SEND" then
                        if message.mail == nil then
                            respondFail(message.origin, "MALFORMED_REQUEST", "Missing mail object")
                            return true
                        end
                        
                        local mail = message.mail
                        for i = 1, #mail.to do
                            local to = mail.to[i]
                            local toA = to:split("@")
                            if #toA == 1 or toA[2] == hostname then
                                if users[toA[1]] == nil then
                                    respondFail(message.origin, "UNKNOWN_USER", to)
                                    return true
                                end
                            else

                            end
                        end

                        mail.from = user.username.."@"..hostname
                        local uuid = hostname.."."..tostring(rmail.cUUID)
                        mail.uuid = uuid
                        mail.time = os.epoch('utc')
                        rmail.cUUID = rmail.cUUID+1

                        ---@diagnostic disable-next-line: assign-type-mismatch
                        rmail[uuid] = {
                            uuid = uuid,
                            time = mail.time,
                            from = mail.from,
                            to = mail.to,
                            subject = mail.subject
                        }
                        user.mail[uuid] = true
                        save()

                        local f = fs.open(dirPath .. uuid .. ".rmail", "w")
                        if f then
                            f.write(textutils.serialiseJSON(mail))
                            f.close()
                        else
                            log:error('Could not write mail file: '..dirPath..uuid..'.rmail')
                        end
                        
                        for i=1,#mail.to do
                            local to = mail.to[i]
                            local toA = strSplit(to, "@")
                            if #toA == 1 or toA[2] == hostname then
                                users[toA[1]].mail[uuid] = true
                            end
                        end
                        respondSent(message.origin, uuid)
                        return true
                    elseif message.method == "GET" then
                        if message.mailUUID == nil then
                            respondFail(message.origin, "MALFORMED_REQUEST", "Missing mail uuid")
                            return true
                        end
                        
                        local uuid = message.mailUUID
                        local canGet = false
                        if user.mail[uuid] == true then
                            -- goto get_continue
                            canGet = true
                        else
                            local mail = rmail[uuid]
                            if mail == nil then
                                respondFail(message.origin, "INVALID_UUID", "No mail with uuid "..uuid)
                                return true
                            end
                            for usr in mail.to do
                                if usr == user.username then
                                    -- goto get_continue
                                    canGet = true
                                end
                            end
                        end
                        -- ::get_continue::
                        if canGet then
                            local f = fs.open(dirPath .. uuid .. ".rmail", "r")
                            if f == nil then
                                respondFail(message.origin, "INTERNAL_ERROR", "Somthign went wrong loading the mail id '" .. uuid .. "'")
                                print("ERROR: Failed to load mail with id '"..uuid.."'")
                                return true
                            end
                            local mail = textutils.unserialiseJSON(f.readAll())
                            f.close()
                            respondMail(message.origin, mail)
                            return true
                        end
                        respondFail(message.origin, "UNAUTHORIZED", "You do not have access to the mail with uuid "..uuid)
                        return true
                    elseif message.method == "LIST" then
                        local list = {}
                        for uuid,_ in pairs(user.mail) do
                            list[uuid] = rmail[uuid]
                        end
                        respondList(message.origin, list)
                        return true
                    else
                        respondFail(message.origin, "MALFORMED_REQUEST", "Invalid method: 'SEND', 'GET', 'LIST'")
                        return true
                    end
                    respondFail(message.origin, "INTERNAL_ERROR", "Unknown error in server")
                    print("ERROR: On method "..message.method.."; Exited proper path")
                    return true
                end
            end
        end
    elseif event[1] == "net_message" then
        local _, msg = unpack(event)
        if msg.port ~= net.standardPorts.rmail or msg.header.type ~= "rmail" then return true end
        ---@cast msg RMail.Messages.Server

        local user = authUser(msg.body.user)
        if user == nil then
            -- respondFail(message.origin, "INVALID_CREDENTIALS")
            net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=false, rtype="INVALID_CREDENTIALS" }, {})
            return true
        end
        if user.mail == nil then
            user.mail = {}
        end
        -- print(textutils.serialise(msg))
        for k,_ in pairs(msg) do
            print(k)
        end

        if msg.header.method == "SEND" then
            local mail = msg.body.mail --[[@as RMail.Mail[]]
            for i = 1, #mail.to do
                local to = mail.to[i]
                local toA = to:split("@")
                if #toA == 1 or toA[2] == hostname then
                    if users[toA[1]] == nil then
                        -- respondFail(message.origin, "UNKNOWN_USER", to)
                        net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=false, rtype="UNKNOWN_USER", rtext=to }, {})
                        return true
                    end
                else

                end
            end

            mail.from = user.username.."@"..hostname
            local uuid = hostname.."."..tostring(rmail.cUUID)
            mail.uuid = uuid
            mail.time = os.epoch('utc')
            rmail.cUUID = rmail.cUUID+1

            ---@diagnostic disable-next-line: assign-type-mismatch
            rmail[uuid] = {
                uuid=uuid,
                time=mail.time,
                from=mail.from,
                to=mail.to,
                subject=mail.subject
            }
            user.mail[uuid] = true
            save()

            local f = fs.open(dirPath .. uuid .. ".rmail", "w")
            if f then
                f.write(textutils.serialiseJSON(mail))
                f.close()
            else
                log:error('Could not write to mail file: '..dirPath..uuid..'.rmail')
            end
            
            for i=1,#mail.to do
                local to = mail.to[i]
                local toA = to:split('@')
                if #toA == 1 or toA[2] == hostname then
                    users[toA[1]].mail[uuid] = true
                end
            end
            -- respondSent(message.origin, uuid)
            net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=true, rtype="SENT" }, { mailUUID=uuid})
            return true
        elseif msg.header.method == "GET" then
            local uuid = msg.body.mailUUID
            local canGet = false
            if user.mail[uuid] == true then
                -- goto get_continue
                canGet = true
            else
                local mail = rmail[uuid]
                if mail == nil then
                    -- respondFail(message.origin, "INVALID_UUID", "No mail with uuid "..uuid)
                    net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=false, rtype="INVALID_UUID", rtext="No mail with uuid "..uuid }, {})
                    return true
                end
                for usr in mail.to do
                    if usr == user.username then
                        -- goto get_continue
                        canGet = true
                    end
                end
            end
            -- ::get_continue::
            if canGet then
                local f = fs.open(dirPath .. uuid .. ".rmail", "r")
                if f == nil then
                    -- respondFail(message.origin, "INTERNAL_ERROR", "Somthign went wrong loading the mail id '" .. uuid .. "'")
                    net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=false, rtype="INTERNAL_ERROR", rtext="Somthign went wrong loading the mail id '" .. uuid .. "'" }, {})
                    print("ERROR: Failed to load mail with id '"..uuid.."'")
                    return true
                end
                local mail = textutils.unserialiseJSON(f.readAll())
                f.close()
                -- respondMail(message.origin, mail)
                net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=true, rtype="MAIL", }, { mail=mail })
                return true
            end
            -- respondFail(message.origin, "UNAUTHORIZED", "You do not have access to the mail with uuid "..uuid)
            net.reply(net.standardPorts.rmail, msg, { type="rmail", cmpt=false, rtype="UNAUTHORIZED", rtext="You do not have access to the mail with uuid "..uuid }, {})
            return true
        elseif msg.header.method == "LIST" then
            local list = {}
            for uuid,_ in pairs(user.mail) do
                list[uuid] = rmail[uuid]
            end
            -- respondList(msg.body.origin, list)
            net.reply(net.standardPorts.rmail, msg, { type = "rmail", cmpt = true, rtype = "LIST" }, { list = list })
            log:debug('Got list message for '..user.username..' and returned '..#user.mail..' rmails')
            return true
        end
        net.reply(net.standardPorts.rmail, msg,
            { type = "rmail", cmpt = false, rtype = "UNKNOWN_METHOD", rtext = 'Method "'..msg.header.method..'" is not valid' },
            { }
        )
        log:debug('Unknown method: '..msg.header.method)
    elseif event[1] == "terminate" then
        return false
    elseif event[1] == "char" then
        cmd = cmd .. event[2]
        drawCmd()
    elseif event[1] == "key" then
        if event[2] == keys.enter and event[3] == false then
            print("")
            if not prossessCommand(cmd) then
                return false
            end
            cmd = ""
            drawCmd()
        elseif event[2] == keys.backspace then
            cmd = string.sub(cmd, 1, -2)
            drawCmd()
        end
    end
    return true
end

if not setup() then
    return
end
local cont = true
drawCmd()
while cont do
    cont = loop()
end
print("Terminating server")

close()
save()

print("User and mail tables saved")
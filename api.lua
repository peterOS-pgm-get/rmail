local api = {} ---@class RMail.API
local log = pos.Logger('rmailAPI.log')
api.log = log

local dta = {}
---@diagnostic disable-next-line: missing-fields
dta.user = {} ---@type RMail.User
dta.server = ''

---Get the current user information
---@return RMail.User user
function api.getUser()
    return dta.user
end

---Set the current user information
---@param user RMail.User new user information
function api.setUser(user)
    dta.user = user
end

---Get the current rMail server
---@return string server
function api.getServer()
    return dta.server
end

---Set the current rMail server
---@param server string new rMail server
function api.setServer(server)
    dta.server = server
end

local readMail = {} ---@type { string: boolean }
---Mark mail as read by UUID
---@param uuid string
function api.setRead(uuid)
    if readMail[uuid] ~= true then
        api.msgServer('MARK_READ', { uuid = uuid })
    end
end
---Check if mail with UUID is read
---@param uuid string UUID to check
---@return boolean read
function api.isRead(uuid)
    return readMail[uuid] == true
end

local cfgPath = '/home/.appdata/rmail/'

function api.saveConfig()
    local uf = fs.open(cfgPath..'user.json', 'w')
    if not uf then
        log:error('Could not save user to file')
        return
    end
    uf.write(textutils.serialiseJSON(dta.user))
    uf.close()
    log:info('Saved user to file')
    
    local cf = fs.open(cfgPath..'cfg.json', 'w')
    if not cf then
        log:error('Could not save config to file')
        return
    end
    cf.write(textutils.serialiseJSON({
        server = dta.server
    }))
    cf.close()
    log:info('Saved config to file')
end

local msgHandlerId = -1

local inited = false
function api.init()
    if inited then
        return true
    end
    log:info('Starting rMail API')
    if fs.exists(cfgPath .. 'user.json') then
        local f = fs.open(cfgPath .. 'user.json', 'r')
        if not f then
            log:fatal('Could not access user config file')
            return false
        end
        local cfg = textutils.unserialiseJSON(f.readAll())
        f.close()
        if not cfg or (not cfg.name) or (not cfg.pass) then
            log:fatal('User config file corrupted')
            return false
        end
        dta.user = cfg
        log:info('Loaded user config file')
        -- log:debug(textutils.serialise(dta.user))
    else
        log:warn('Could not find user config file, creating it')
        local f = fs.open(cfgPath .. 'user.json', 'w')
        if not f then
            log:fatal('Could not write to user config file')
            return false
        end
        f.write(textutils.serialiseJSON({ name = '', pass = '' }))
        f.close()
    end

    if fs.exists(cfgPath .. 'cfg.json') then
        local f = fs.open(cfgPath .. 'cfg.json', 'r')
        if not f then
            log:fatal('Could not access config file')
            return false
        end
        local cfg = textutils.unserialiseJSON(f.readAll())
        f.close()
        if not cfg or (not cfg.server) then
            log:fatal('Config file corrupted')
            return false
        end
        dta.server = cfg.server
        log:info('Loaded config file')
    else
        log:warn('Could not find config file, creating it')
        local f = fs.open(cfgPath .. 'cfg.json', 'w')
        if not f then
            log:fatal('Could not write to user config file')
            return false
        end
        f.write(textutils.serialiseJSON({ server = '' }))
        f.close()
    end

    msgHandlerId = net.registerMsgHandler(api._handleMsg)

    log:info('API initialized')
    inited = true
    return true
end

function api.dispose()
    net.unregisterMsgHandler(msgHandlerId)
end

-- dta.mail = {}
dta.mailList = {} ---@type RMail.Mail[]
dta.mail = {} ---@type table<string, RMail.Mail>

api.updateMailList = function(list) end ---@type fun(mail: RMail.Mail[])

---*INTERNAL* Message handler functions
---@param msg NetMessage
function api._handleMsg(msg)
    if msg.port ~= net.standardPorts.rmail or msg.header.type ~= "rmail" then return end
    ---@cast msg RMail.Messages.Server
    -- log:debug('msg')
    -- log:debug(net.stringMessage(msg))
    if msg.header.cmpt == false then
        local err = "Connection Error: " .. msg.header.rtype
        log:error(err)
        return
    end

    if msg.header.rtype == "MAIL" then
        dta.mail[msg.body.mail.uuid] = msg.body.mail
        log:debug('Received mail data')
    elseif msg.header.rtype == "LIST" then
        dta.mailList = msg.body.list
        readMail = msg.body.read
        log:debug("Got rmail list")
        api.updateMailList(dta.mailList)
    elseif msg.header.rtype == "SENT" then
        -- local msg = {
        --     method="GET",
        --     user=user,
        --     mailUUID=msg.body.mailUUID
        -- }
        -- send(msg)
        -- net.sendAdv(net.standardPorts.rmail, mailserver,
        --     { type = "rmail", method = "GET" },
        --     { mailUUID = msg.body.mailUUID, user = user }
        -- )
        -- draft = nil
        api.msgServer('GET', { mailUUID = msg.body.mailUUID, user = dta.user })
    elseif msg.header.rtype ~= 'OK' then
        log:warn('Unknown message type: ' .. tostring(msg.header.rtype))
    end
end

---Send a message to the current rMail server
---@param method RMailMessages.Client.Method
---@param body RMail.Messages.Client.Body
function api.msgServer(method, body)
    if not body then body = {} end
    if not body.user then
        body.user = dta.user
    end
    net.sendAdv(net.standardPorts.rmail, dta.server,
        { type = "rmail", method = method },
        body
    )
end

function api.refresh()
    api.msgServer('LIST', { user = dta.user })
    log:debug('Refreshing list')
end

---Send a new mail to the rMail server
---@param mail RMail.Messages.Client.Mail
function api.send(mail)
    if (not mail.to) or (not mail.subject) or (not mail.body) then
        log:warn('Tried to send message missing components')
        return
    end
    api.msgServer('SEND', { user = dta.user, mail = mail })
    log:debug('Sending mail')
end

---Get mail by UUId
---@param uuid string
---@return RMail.Mail
function api.getMail(uuid)
    api.msgServer('GET', { mailUUID = uuid, user = dta.user })
    log:debug('Getting mail `' .. uuid .. '`')

    while not dta.mail[uuid] do
        os.pullEvent()
    end
    return dta.mail[uuid]
end

---Get mail objects sorted by time
---@param mail RMail.Mail[]
---@return fun():integer,RMail.Mail iterator
function api.pairsByTime(mail)
    local arr = {}
    for n in pairs(mail) do table.insert(arr, n) end
    table.sort(arr, function(a,b)
        return mail[a].time > mail[b].time
    end)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if arr[i] == nil then return nil
            else return arr[i], mail[arr[i]]
        end
    end
    return iter
end

return api

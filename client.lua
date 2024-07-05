---@diagnostic disable
local Logger = pos.require('logger')
local log = Logger('/home/.pgmLog/rmail.log')
log:info('Staritng rMail')

net.setup()

local mailserver = "rmail"
local cfgPath = "/home/.appdata/rmail/cfg.json"
local userPath = "/home/.appdata/rmail/user.json"
if fs.exists(cfgPath) then
    local f = fs.open(cfgPath, "r")
    if f ~= nil then
        local cfg = textutils.unserialiseJSON(f.readAll())
        f.close()
        mailserver = cfg.server
    end
end

local modem = nil
local id = os.getComputerID()
local port = 10025
local function setup()
    if not (modem == nil) then return true end
    local modems = { peripheral.find("modem", function(name, mdm)
        return mdm.isWireless()
    end) }
    if #modems == 0 then
        error("No Modem Attached", 0)
        return false
    end
    modem = modems[1]
    modem.open(port)
    return true
end
local function close()
    if(modem) then modem.close(port) end
    modem = nil
end
-- local function send(body)
--     body.type = "rmail"
--     body.host = body.host or mailserver
--     body.origin = id
--     body.meta = body.meta or {}
--     modem.transmit(port, port, body)
-- end

local function strSplit (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local user = {
    name="username",
    pass="password"
}

if fs.exists(userPath) then
    local f = fs.open(userPath, "r")
    if f ~= nil then
        local c = f.readAll()
        local tu = textutils.unserialiseJSON(c)
        f.close()
        if tu ~= nil then
            user = tu
            log:info('Loaded user file')
        else
            log:error('User file was malformed')
            log:info(c)
        end
    else
        log:error("User file access error")
    end
else
    log:warn('User file did not exist')
end

local list = {}
local listOrd = {}
local mail = nil
local mailList = {}
local draft = nil
local sw, sh = term.getSize()

local function pairsByTime(t)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
---@diagnostic disable-next-line: redefined-local
    table.sort(a, function(a,b)
        return t[a].time > t[b].time
    end)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
            else return a[i], t[a[i]]
        end
    end
    return iter
end

local function clear()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.white)
    term.setCursorPos(1,1)
end

local scroll = 1
local cpage = "LIST"
local focusID = -1
local blinkState = false
local err = ""

local function gotoPage(page)
    if page == nil then
        cpage = "ERROR"
        err = "Tried to set page to "..page;
    else
        cpage = page
    end
    scroll = 1
end

local function drawListPage()
    if scroll > #list-(sh-3) then
        scroll = #list-(sh-3)
    end
    if scroll < 1 then
        scroll = 1
    end
    listOrd = {}

    clear()
    term.setBackgroundColor(colors.gray)
    term.write("*")
    term.setBackgroundColor(colors.black)
    term.write("Mail List:")
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(25, 1)
    term.write("Draft")
    term.setCursorPos(sw-1, 1)
    term.setTextColor(colors.green)
    term.write("X")
    term.setTextColor(colors.red)
    term.write("X")
    
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    local l = 1 - (scroll-1)
    for uuid,m in pairsByTime(list) do
        if l >= 1 then
            if l%2 == 0 then
                -- paintutils.drawBox(1,l+2,sw,l+2, colors.gray)
                -- term.setBackgroundColor(colors.gray)
            else
                -- paintutils.drawBox(1,l+2,sw,l+2, colors.lightGray)
                -- term.setBackgroundColor(colors.lightGray)
            end
            if m.from == user.name.."@"..mailserver then
                term.setTextColor(colors.orange)
            else
                term.setTextColor(colors.green)
            end
            local str = " | " .. m.subject
            term.setCursorPos(1,l+2)
            term.write(m.from)
            term.setTextColor(colors.white)
            term.write(str)
            listOrd[l]=uuid
        end
        l=l+1
        if l > sh-2 then
            break
        end
    end
    term.setBackgroundColor(colors.black)
end

local function drawDraftPage()
    if draft == nil then
        draft = {
            to="",
            subject="",
            body=""
        }
    end
    if focusID > 2 then
        focusID = -1
    end
    
    clear()
    term.write("Draft Mail:")
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(25, 1)
    term.write("Send")
    term.setCursorPos(sw-2, 1)
    term.write(" X")
    term.setTextColor(colors.red)
    term.write("X")

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1,3)
    term.write("To:")
    paintutils.drawFilledBox(4,3,sw,3, colors.gray)
    term.setCursorPos(4, 3)
    draft.to = string.sub(draft.to, 1, sw-4)
    term.write(draft.to)
    if focusID == 0 and blinkState  then
        term.setTextColor(colors.lightGray)
        term.write("_")
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1,4)
    term.write("Subject:")
    paintutils.drawFilledBox(9,4,sw,4, colors.gray)
    term.setCursorPos(9,4)
    draft.subject = string.sub(draft.subject, 1, sw-9)
    term.write(draft.subject)
    if focusID == 1 and blinkState  then
        term.setTextColor(colors.lightGray)
        term.write("_")
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1,5)
    term.write("Body:")
    paintutils.drawFilledBox(1,6,sw,sh, colors.gray)
    term.setCursorPos(1, 6)
    draft.body = draft.body:sub(1, sw * (sh-5))
    if draft.body:len() <= sw then
        term.write(draft.body)
    else
        local nLines = draft.body:len() / sw
        nLines = math.ceil(nLines)
        for i=1, nLines do
            term.setCursorPos(1, 5 + i)
            local sI = (i - 1) * sw + 1
            local eI = i * sw
            term.write(draft.body:sub(sI, eI))
        end
    end
    if focusID == 2 and blinkState then
        term.setTextColor(colors.lightGray)
        term.write("_")
    end
end

local function drawMailPage()

    clear()
    term.write("Mail: "..cpage)
    term.setBackgroundColor(colors.gray)
    -- term.setCursorPos(15, 1)
    -- term.write("Reply")
    term.setCursorPos(sw-2, 1)
    term.write(" X")
    term.setTextColor(colors.red)
    term.write("X")

    if mail == nil then
        if mailList[cpage] ~= nil then
            mail = mailList[cpage]
        else
            return
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1,3)
    term.write("From: ")
    term.write(mail.from)

    term.setTextColor(colors.white)
    term.setCursorPos(1,4)
    term.write("To: ")
    for i=1,#mail.to do
        if i > 1 then term.write(",") end
        term.write(mail.to[i])
    end

    term.setTextColor(colors.white)
    term.setCursorPos(1,5)
    term.write("Subject: ")
    term.write(mail.subject)

    term.setTextColor(colors.white)
    term.setCursorPos(1,6)
    term.write("Body:")
    term.setCursorPos(1,7)
    term.write(mail.body)
end

local function drawErrorPage()
    if err == "" then
        gotoPage("LIST")
        return
    end
    clear()
    term.write("Error:")
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(sw-2, 1)
    term.write(" X")
    term.setTextColor(colors.red)
    term.write("X")

    term.setBackgroundColor(colors.black)
    term.setCursorPos(1,3)
    term.write(err)
end

local function drawDebugPage()
    clear()
    term.write("Debug:")
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(sw-2, 1)
    term.write(" X")
    term.setTextColor(colors.red)
    term.write("X")
    
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1,3)
    term.write("Server: `" .. mailserver .. "'")

    term.setCursorPos(1,4)
    term.write("User: `" .. user.name .. "'")
    term.setCursorPos(1,5)
    term.write("Pass: `" .. user.pass .. "'")
    
    if draft ~= nil then
        term.setCursorPos(1,7)
        term.write("Draft to: `" .. draft.to .. "'")
        term.setCursorPos(1,8)
        term.write("Draft to arr: `" .. textutils.serialise(strSplit(draft.to, ",")) .. "'")
    end
end

local function draw()
    if cpage == "ERROR" then
        drawErrorPage()
    elseif cpage == "DRAFT" then
        drawDraftPage()
    elseif cpage == "LIST" then
        drawListPage()
    elseif cpage == "DEBUG" then
        drawDebugPage()
    else
        drawMailPage()
    end
end

local function refreshList()
    -- local body = {
    --     method = "LIST",
    --     user = user
    -- }
    -- send(body)
    net.sendAdv(net.standardPorts.rmail, mailserver,
        { type = "rmail", method = "LIST" },
        { user = user }
    )
    log:debug('Refreshing list')
end

local timeoutTimer = nil
local blinkTimer = os.startTimer(0.5)

local function loop()
    draw()
    local event = { os.pullEventRaw() }
    if event[1] == "terminate" then
        return false
    elseif event[1] == "mouse_click" then
        local eventN, button, x, y = unpack(event)
        if cpage == "DEBUG" or cpage == "ERROR" then -- error/debug pages
            if y == 1 then
                if x == sw then
                    return false
                elseif x == sw-1 then
                    gotoPage("LIST")
                end
            end
        elseif cpage == "DRAFT" then -- draft page
            focusID = -1
            if y == 1 then
                if x == sw then
                    return false
                elseif x == sw-1 then
                    gotoPage("LIST")
                elseif x >= 25 and x <= 28 then
                    if draft.to == "" or draft.subject == "" or draft.body == "" then
                        gotoPage("ERROR")
                        err = "Must have to, subject and body"
                        return true
                    end
                    local newMail = {
                        to = strSplit(draft.to, ","),
                        subject = draft.subject,
                        body = draft.body
                    }
                    -- local msg = {
                    --     method = "SEND",
                    --     user = user,
                    --     mail = mail
                    -- }
                    -- send(msg)
                    net.sendAdv(net.standardPorts.rmail, mailserver,
                        { type = "rmail", method = "SEND" },
                        { mail = newMail, user = user }
                    )
                    gotoPage("LIST")
                    refreshList()
                    return true
                end
            elseif y == 3 then
                focusID = 0
            elseif y == 4 then
                focusID = 1
            elseif y > 5 then
                focusID = 2
            end
        elseif cpage == "LIST" then -- list page
            if y == 1 then
                if x == sw then
                    return false
                elseif x == sw-1 then
                    gotoPage("DEBUG")
                elseif x >=25 and x <= 29 then
                    gotoPage("DRAFT")
                elseif x == 1 then
                    refreshList()
                end
            elseif y > 2 and y <= #listOrd+2 then -- goto mail page
                local uuid = listOrd[y-2]
                gotoPage(uuid)
                if mailList[uuid] == nil then
                    mail = nil
                    -- local msg = {
                    --     method="GET",
                    --     user=user,
                    --     mailUUID=uuid
                    -- }
                    -- send(msg)
                    
                    net.sendAdv(net.standardPorts.rmail, mailserver,
                        { type = "rmail", method = "GET" },
                        { mailUUID = uuid, user = user }
                    )
                    timeoutTimer = os.startTimer(2)
                    return true
                end
                mail = mailList[uuid]
            end
        else -- mail veiw page
            if y == 1 then
                if x == sw then
                    return false
                elseif x == sw-1 then
                    gotoPage("LIST")
                end
            end
        end
    elseif event[1] == "char" then
        if cpage == "DRAFT" then
            if focusID == 0 then
                draft.to = draft.to .. event[2]
            elseif focusID == 1 then
                draft.subject = draft.subject .. event[2]
            elseif focusID == 2 then
                draft.body = draft.body .. event[2]
            end
        end
    elseif event[1] == "key" then
        if event[2] == keys.tab and event[3] == false then
            focusID = focusID + 1
        elseif event[2] == keys.backspace then
            if cpage == "DRAFT" then
                if focusID == 0 then
                    draft.to = string.sub(draft.to, 1, -2)
                elseif focusID == 1 then
                    draft.subject = string.sub(draft.subject, 1, -2)
                elseif focusID == 2 then
                    draft.body = string.sub(draft.body, 1, -2)
                end
            end
        end
    elseif event[1] == "modem_message" then
        local eName, side, channel, replyChannel, message, distance = unpack(event)
        if channel == port and message.type == "rmail" and message.host == id then
            if timeoutTimer ~= nil then
                os.cancelTimer(timeoutTimer)
            end
            if message.rsp.cmpt == false then
                err = "Connection Error: " .. message.rsp.type.."\n"..message.rsp.text
                gotoPage("ERROR")
            elseif message.rsp.type == "MAIL" then
                mailList[message.mail.uuid] = message.mail
            elseif message.rsp.type == "LIST" then
                list = message.list
            elseif message.rsp.type == "SENT" then
                -- local msg = {
                --     method="GET",
                --     user=user,
                --     mailUUID=message.mailUUID
                -- }
                -- send(msg)
                net.sendAdv(net.standardPorts.rmail, mailserver,
                    { type = "rmail", method = "GET" },
                    { mailUUID = msg.body.mailUUID, user = user }
                )
                draft = nil
            end
        end
    elseif event[1] == "net_message" then
        local _, msg = unpack(event)
        if msg.port ~= net.standardPorts.rmail or msg.header.type ~= "rmail" then return true end
        if msg.header.cmpt == false then
            err = "Connection Error: " .. msg.header.rtype .. "\n" .. msg.header.rtext
            gotoPage("ERROR")
            log:error(err)
        elseif msg.header.rtype == "MAIL" then
            mailList[msg.body.mail.uuid] = msg.body.mail
        elseif msg.header.rtype == "LIST" then
            list = msg.body.list
            log:debug("Got rmail list")
        elseif msg.header.rtype == "SENT" then
            -- local msg = {
            --     method="GET",
            --     user=user,
            --     mailUUID=msg.body.mailUUID
            -- }
            -- send(msg)
            net.sendAdv(net.standardPorts.rmail, mailserver,
                { type = "rmail", method = "GET" },
                { mailUUID = msg.body.mailUUID, user = user }
            )
            draft = nil
        else
            log:warn('Unknonw message type: '..msg.header.rtype)
        end
    elseif event[1] == "timer" then
        if event[2] == timeoutTimer then
            err = "Connection Timeout: No further information"
            gotoPage("ERROR")
        elseif event[2] == blinkTimer then
            blinkTimer = os.startTimer(0.5)
            blinkState = not blinkState
        end
    end
    return true
end

setup()
refreshList()
local cont = true
while cont do
    cont = loop()
end
close()
clear()
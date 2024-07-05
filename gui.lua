local api = ... ---@type RMail.API

local gui = {} ---@class RMail.GUI

--- Main Window
local win = {}
gui.win = win

--- User window
local sWin = {}
gui.sWin = sWin
sWin.window = pos.gui.Window('Settings', colors.blue)
sWin.window:setSize(32, 8)
sWin.window:setPos(8, 3)
sWin.window.exitOnHide = false
sWin.winId = pos.gui.addWindow(sWin.window)
sWin.window:hide()

sWin.userText = pos.gui.TextBox(1, 2, colors.blue, colors.white, 'User:', 5)
sWin.window:addElement(sWin.userText)
sWin.userInput = pos.gui.TextInput(6, 2, 16, colors.gray, colors.white, function(text) end)
sWin.window:addElement(sWin.userInput)

sWin.passText = pos.gui.TextBox(1, 3, colors.blue, colors.white, 'Pass:')
sWin.window:addElement(sWin.passText)
sWin.passInput = pos.gui.TextInput(6, 3, 16, colors.gray, colors.white, function(text) end)
sWin.passInput.hideText = true
sWin.window:addElement(sWin.passInput)
sWin.userInput.next = sWin.passInput

sWin.serverText = pos.gui.TextBox(1, 5, colors.blue, colors.white, 'Server:')
sWin.window:addElement(sWin.serverText)
sWin.serverInput = pos.gui.TextInput(8, 5, 14, colors.gray, colors.white, function(text) end)
sWin.window:addElement(sWin.serverInput)
sWin.passInput.next = sWin.serverInput

sWin.saveBtn = pos.gui.Button(4, 7, 6, 1, colors.green, colors.white, ' Save ', function(btn)
    local userCfg = {
        name = sWin.userInput.text,
        pass = sWin.passInput.text,
    }
    local server = sWin.serverInput.text
    -- Save user config here
    api.setUser(userCfg)
    api.setServer(server)
    api.saveConfig()
end)
sWin.window:addElement(sWin.saveBtn)

function sWin.update()
    local user = api.getUser()
    local server = api.getServer()
    if(user.name) then sWin.userInput:setText(user.name) end
    if(user.pass) then sWin.passInput:setText(user.pass) end
    if(server) then sWin.serverInput:setText(server) end
end

--- Draft window
local dWin = {}
gui.dWin = dWin
dWin.window = pos.gui.Window('Draft', colors.black)
dWin.window.exitOnHide = false
dWin.winId = pos.gui.addWindow(dWin.window)
dWin.window:hide()

dWin.sendBtn = pos.gui.Button(1, 2, 4, 1, colors.green, colors.white, 'Send', function(btn)
    local mail = {}
    mail.to = dWin.toInput.text:split(',')
    mail.subject = dWin.subjectInput.text
    mail.body = dWin.bodyInput.text
    -- Send mail here
    api.send(mail)
    api.refresh()
    dWin.window:hide()
    win.window:show()
end)
dWin.window:addElement(dWin.sendBtn)

dWin.sendBtn = pos.gui.Button(6, 2, 4, 1, colors.red, colors.white, 'Clear', function(btn)
    dWin.toInput:setText('')
    dWin.subjectInput:setText('')
    dWin.bodyInput:setText('')
end)
dWin.window:addElement(dWin.sendBtn)

dWin.toText = pos.gui.TextBox(1, 3, colors.gray, colors.white, 'To ')
dWin.window:addElement(dWin.toText)
dWin.toInput = pos.gui.TextInput(4, 3, dWin.window.w - 4, colors.gray, colors.white, function(text) end)
dWin.window:addElement(dWin.toInput)

dWin.subjectText = pos.gui.TextBox(1, 4, colors.gray, colors.white, 'Subject ')
dWin.window:addElement(dWin.subjectText)
dWin.subjectInput = pos.gui.TextInput(9, 4, dWin.window.w - 9, colors.gray, colors.white, function(text) end)
dWin.window:addElement(dWin.subjectInput)
dWin.toInput.next = dWin.subjectInput

dWin.bodyText = pos.gui.TextBox(1, 5, colors.black, colors.white, 'Body')
dWin.window:addElement(dWin.bodyText)
dWin.bodyInput = pos.gui.TextInput(1, 6, dWin.window.w, colors.gray, colors.white, function(text) end)
dWin.bodyInput.submitable = false
dWin.bodyInput.h = dWin.window.h - 6
dWin.window:addElement(dWin.bodyInput)
dWin.subjectInput.next = dWin.bodyInput

function dWin.reply(mail)
    dWin.toInput:setText(mail.from)
    dWin.subjectInput:setText('Re: ' .. mail.subject)
    dWin.bodyInput:setText('')
    dWin.window:show()
end

--- Mail viewer page
local mWin = {}
gui.mWin = mWin
mWin.mail = { to = { '' }, from = '', subject = '', body = '', uuid = '', time = -1 }
mWin.window = pos.gui.Window('rMail - ', colors.black)
mWin.window.exitOnHide = false
mWin.winId = pos.gui.addWindow(mWin.window)
mWin.window:hide()

mWin.option = pos.gui.MenuOption(1, 'Options', { 'Reply' }, 8, function(index, option)
    if index == 1 then
        dWin.reply(mWin.mail)
    end
    mWin.option.visible = false
end)
mWin.window:addMenuOption(mWin.option)

mWin.fromText = pos.gui.TextBox(1, 2, nil, nil, 'From:', mWin.window.w-8)
mWin.window:addElement(mWin.fromText)
mWin.toText = pos.gui.TextBox(1, 3, nil, nil, 'To:', mWin.window.w)
mWin.window:addElement(mWin.toText)

mWin.timeText = pos.gui.TextBox(mWin.window.w - 7, 2, nil, nil, 'mm/dd/yy')
mWin.window:addElement(mWin.timeText)

mWin.subjectText = pos.gui.TextBox(1, 4, nil, nil, '', mWin.window.w)
mWin.window:addElement(mWin.subjectText)

mWin.bodyScroll = pos.gui.ScrollField(1, 6, mWin.window.w, mWin.window.h - 6)
mWin.window:addElement(mWin.bodyScroll)
mWin.bodyText = pos.gui.TextBox(1, 1, nil, nil, '', mWin.window.w)
mWin.bodyScroll:addElement(mWin.bodyText)

function mWin.update(uuid)
    api.setRead(uuid)
    local mail = api.getMail(uuid)
    mWin.mail = mail
    mWin.window:setName('rMail - ' .. mail.subject)
    mWin.fromText:setText('From: '..mail.from)
    mWin.toText:setText('To: ' .. table.concat(mail.to, ','))
    mWin.timeText:setText(os.date('%x', mail.time / 1000) --[[@as string]])
    mWin.subjectText:setText(mail.subject)
    mWin.bodyText:setText(mail.body)
end

--- Main window

win.window = pos.gui.Window('rMail')
local w, h = win.window.w, win.window.h
win.winId = pos.gui.addWindow(win.window)
win.option = pos.gui.MenuOption(1, 'Options', { 'Draft', 'User', 'Refresh' }, 8, function(index, option)
    if index == 1 then
        dWin.window:show()
    elseif index == 2 then
        sWin.update()
        sWin.window:show()
    elseif index == 3 then
        -- Refresh
        api.refresh()
    end
    win.option.visible = false
end)
win.window:addMenuOption(win.option)

win.list = pos.gui.ScrollField(1, 2, win.window.w, win.window.h - 1)
win.window:addElement(win.list)

win.mailBtns = {} ---@type UiElement[]
---Update mail list
---@param mailList RMail.Mail[]
function gui.setMail(mailList)
    for id, btn in pairs(win.mailBtns) do
        win.list:removeElement(id)
    end
    win.mailBtns = {}
    local y = 1
    local user = api.getUser()
    local mailServer = api.getServer()

    local sentMail = {}
    for _, mail in api.pairsByTime(mailList) do
        if mail.from ~= user.name .. "@" .. mailServer then
            local text = mail.from .. ' | ' .. mail.subject .. ' | ' .. os.date('%x', mail.time / 1000)
            local color = colors.green
            if api.isRead(mail.uuid) then
                color = colors.lightGray
            end
            local btn
            btn = pos.gui.Button(1, y, win.window.w, 1, colors.black, color, text, function(_)
                -- api.log:debug(textutils.serialise(mail))
                mWin.update(mail.uuid)
                mWin.window:show()
                btn.fg = colors.lightGray
            end)
            local id = win.list:addElement(btn)
            win.mailBtns[id] = btn
            y = y + 1
        else
            sentMail[mail.uuid] = mail
        end
    end

    local sep = pos.gui.TextBox(1, y, colors.gray, colors.white, ' -- Sent --', win.window.w)
    local sepId = win.list:addElement(sep)
    win.mailBtns[sepId] = sep
    y = y + 1

    for _, mail in api.pairsByTime(sentMail) do
        api.setRead(mail.uuid)
        local text = mail.to[1] .. ' | ' .. mail.subject .. ' | ' .. os.date('%x', mail.time / 1000)
        local btn = pos.gui.Button(1, y, win.window.w, 1, colors.black, colors.orange, text, function(btn)
            -- api.log:debug(textutils.serialise(mail))
            mWin.update(mail.uuid)
            mWin.window:show()
        end)
        local id = win.list:addElement(btn)
        win.mailBtns[id] = btn
        y = y + 1
    end
    -- api.log:debug('GUI: listing '..(y-1)..' r-mails')
end

api.updateMailList = gui.setMail

function gui.dispose()
    pos.gui.removeWindow(win.winId)
    pos.gui.removeWindow(sWin.winId)
    pos.gui.removeWindow(dWin.winId)
    pos.gui.removeWindow(mWin.winId)
end

win.window:show()

return gui

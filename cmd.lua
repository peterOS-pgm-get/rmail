local args = { ... }


if args[1] == nil then
    --- Client
    local api = loadfile('/os/bin/rmail/api.lua')() ---@type RMail.API
    api.init()
    local gui = loadfile('/os/bin/rmail/gui.lua')(api) ---@type RMail.GUI
    api.refresh()
    pos.gui.run()

    gui.dispose()
    api.log:info('Closing API')
end
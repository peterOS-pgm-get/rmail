local clientServer = { -- msg to server
    type = "rmail",    -- intersystem typecode
    origin = 0,        -- origin id
    host = "server",   -- server hostname
    method = "SEND",   -- method code ["SEND","GET","LIST"]
    user = {           -- user data object
        name = "username",
        pass = "password"
    },
    mail = {                       -- mail data object; only used for SEND
        to = { "user1", "user2" }, -- array of recipiants
        subject = "Subject Line",  -- mail subject line
        body = ""                  -- body of the mail
    },
    mailUUID = "host.id",          -- mail uuid; only used for GET
    meta = {}                      -- reserved for future use
}

local serverRsp = {                -- rsp from server
    type = "rmail",                -- intersystem typecode
    origin = 0,                    -- server id
    server = "server",             -- server host name
    host = 0,                      -- destination id
    rsp = {                        -- server response
        cmpt = true,               -- if the action completed succesfully
        type = "type",             -- response type ["SENT","LIST","MAIL","UNKNOWN_USER","INVALID_UUID","INVALID_CREDENTIALS","UNAUTHORIZED","MALFORMED_REQUEST","INTERNAL_ERROR"]
        text = "description"       -- description of response; only on error response
    },
    mail = {                       -- mail data object; only on rsp type SENT
        uuid = "host.id",          -- mail unique universal identifier
        time = 0,                  -- time mail was created
        from = "username",         -- user mail is from
        to = { "user1", "user2" }, -- array of recivers
        subject = "Subject Line",  -- mail subject line
        body = ""                  -- body of the mail
    },
    list = {                       -- list of mail; only on rsp type LIST
        [0] = {                    -- mail object
            uuid = "host.id",
            time = 0,
            from = "username",
            to = { "username" },
            subject = "Subject Line"
        }
    },
    mailUUID = "host.id", -- uuid of mail; only on rsp type MAIL
    meta = {}             -- reserved for future use
}

local mail = {                 -- mail object
    uuid = "host.id",          -- mail unique universal identifier
    time = 0,                  -- time mail was created
    from = "username",         -- user mail is from
    to = { "user1", "user2" }, -- array of receivers
    subject = "Subject Line",  -- mail subject line
    body = ""                  -- body of the mail
}

local serverServer = { -- server to server message
    type = "rmail",    -- intersystem type-code
    origin = 0,        -- origin id
    server = "server", -- host name of the origin server
    host = "server",   -- destination server hostname
    method = "PASS",   -- method code ["PASS"]
    mail = {
        --standard mail object
    }
}

---@class RMail.User
---@field name string Username
---@field pass string Password

---@class RMail.Mail
---@field uuid string Mail UUID
---@field time integer Time sent (UTC Epoch milliseconds)
---@field from string Mail origin address
---@field to string[] Mail destination addresses
---@field subject string Subject line
---@field body string Body text

---@class RMail.Messages.Client : NetMessage
---@field header RMail.Messages.Client.Header
---@field body RMail.Messages.Client.Body

---@class RMail.Messages.Client.Header : NetMessage.Header
---@field type "rmail"
---@field method RMailMessages.Client.Method

---@alias RMailMessages.Client.Method
---| 'SEND'
---| 'GET'
---| 'LIST'
---| 'MARK_READ'

---@class RMail.Messages.Client.Body
---@field user RMail.User? Origin user
---@field mail RMail.Messages.Client.Mail? `SEND` only. Mail data object
---@field mailUUID string? `GET` only. Requested mail UUID
---@field meta table? *Reserved for Future Use*

---@class RMail.Messages.Client.Mail
---@field to string[] Mail destination addresses
---@field subject string Subject line
---@field body string Body text

-- NET package messages
local net_port = 10025
local net_clientServer = { -- msg to server
    header = {
        type = "rmail",    -- intersystem type-code
        method = "SEND",   -- method code ["SEND","GET","LIST","MARK_READ"]
    },
    body = {
        user = { -- user data object
            name = "username",
            pass = "password"
        },
        mail = {                       -- mail data object; only used for SEND
            to = { "user1", "user2" }, -- array of recipients
            subject = "Subject Line",  -- mail subject line
            body = ""                  -- body of the mail
        },
        mailUUID = "host.id",          -- mail uuid; only used for GET
        meta = {}                      -- reserved for future use
    }
}

---@class RMail.Messages.Server : NetMessage
---@field header RMail.Messages.Server.Header
---@field body RMail.Messages.Server.Body

---@class RMail.Messages.Server.Header : NetMessage.Header
---@field type "rmail"
---@field cmpt boolean If the action completed successfully
---@field rtype RMail.Messages.Server.RType Response type
---@field rtext string? Error message

---@alias RMail.Messages.Server.RType
---| "OK"
---| "SENT"
---| "LIST"
---| "MAIL"
---| "UNKNOWN_USER"
---| "INVALID_UUID"
---| "INVALID_CREDENTIALS"
---| "UNAUTHORIZED"
---| "MALFORMED_REQUEST"
---| "INTERNAL_ERROR"
---| "OUT_OF_DOMAIN"
---| "UNKNOWN_METHOD"

---@class RMail.Messages.Server.Body
---@field mail RMail.Mail? `SENT` only. Mail data object
---@field list RMail.Mail[]? `LIST` only. List of mail
---@field read { string: boolean }? `LIST` only. Map of read mail UUIDs
---@field mailUUID string? `MAIL` only. UUID of mail
---@field meta table? *Reserved for Future Use*

local net_serverRsp = {        -- rsp from server
    header = {
        type = "rmail",        -- intersystem type-code
        cmpt = true,           -- if the action completed successfully
        rtype = "type",        -- response type ["OK","SENT","LIST","MAIL","UNKNOWN_USER","INVALID_UUID","INVALID_CREDENTIALS","UNAUTHORIZED","MALFORMED_REQUEST","INTERNAL_ERROR","OUT_OF_DOMAIN"]
        rtext = "description", -- description of response; only on error response
    },
    body = {
        mail = {                      -- mail data object; only on rsp type SENT
            uuid = "host.id",         -- mail unique universal identifier
            time = 0,                 -- time mail was created
            from = "username",        -- user mail is from
            -- to={"user1","user2"}, -- array of receivers
            subject = "Subject Line", -- mail subject line
            body = ""                 -- body of the mail
        },
        list = {                      -- list of mail; only on rsp type LIST
            [0] = {                   -- mail object
                uuid = "host.id",
                time = 0,
                from = "username",
                to = { "username" },
                subject = "Subject Line"
            }
        },
        mailUUID = "host.id", -- uuid of mail; only on rsp type MAIL
        meta = {}             -- reserved for future use
    }
}

local net_serverServer = { -- server to server message
    header = {
        type = "rmail",    -- intersystem type-code
        method = "PASS",   -- method code ["PASS"]
    },
    body = {
        mail = {
            --standard mail object
        }
    }
}

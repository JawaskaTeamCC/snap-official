-- MIT License
-- Copyright (c) 2024 Argochamber Interactive
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- Messenger for your friends.
local gl = require 'gl'
local nucleic = require 'nucleic'

--- CONFIG ---
settings.define('messenger.server', {
    description = 'The server to where the messenger app will connect to. Override if you want to run unofficial servers.',
    default = 'msn.com-star.net',
    type = 'string'
})
settings.define('messenger.nick', {
    description = 'Your nickname',
    default = (function()
        local sylabes = {
            'fa', 'fe', 'fi', 'fo', 'fu',
            'ka', 'ke', 'ki', 'ko', 'ku',
            'ga', 'ge', 'gi', 'go', 'gu',
            'ra', 're', 'ri', 'ro', 'ru',
            'ma', 'me', 'mi', 'mo', 'mu',
            'ta', 'te', 'ti', 'to', 'tu',
        }
        local value = ''
        for i=1, math.random(2, 4) do
            value = value .. sylabes[math.random(1, #sylabes)]
        end
        return value
    end)(),
    type = 'string'
})
settings.define('messenger.timeout', {
    description = 'Number of seconds which beyond, the response is deemed unreliable.',
    default = 1,
    type = 'number'
})
settings.define('net.side', {
    description = 'The side where the modem peripheral is attached',
    default = 'back',
    type = 'string'
})
local PROTOCOL_VERSION  = 1
local PROTOCOL_TAG      = 'proto:msn.com-star'

local function server_name()
    return settings.get('messenger.server')
end

local function lookup_server()
    return rednet.lookup(PROTOCOL_TAG, server_name())
end

local host_id

-- Net abstractions
local function send(msg)
    return rednet.send(host_id, msg, PROTOCOL_TAG)
end
local function receive()
    return rednet.receive(PROTOCOL_TAG, settings.get('messenger.timeout'))
end
local function request(msg)
    send(msg)
    local id, message = receive()
    if not id then
        return nil, 'timeout'
    end
    if id ~= host_id then
        printError('Warning: A host is tampering the response, expected host #' .. host_id .. ', signature was #' .. id)
        return nil, 'bad host'
    end
    return message
end

-- Connection is just a lookup for later calls.
local function connect(host)
    rednet.open(settings.get('net.side'))
    host_id = rednet.lookup(PROTOCOL_TAG, host)
    if host_id == nil then
        printError('Could not connect to ' .. host)
        return false
    end
    send { action = 'connect', nick = settings.get('messenger.nick') }
    return true
end

local ui = gl.create_buffer()

-- Text area for messages.
local text_area = gl.TextArea(1, 2, ui.w, ui.h - 2)

local function download_messages()
    local msg, err = request { action = 'download_messages' }
    if err then
        printError('Could not download the messages from server:', err)
        return false
    end
    for _, m in ipairs(msg) do
        text_area:add_message('$b' .. m.who .. '$0 ' .. m.payload)
    end
    return true
end

local function print_system_msg(msg)
    text_area:add_message(msg, colours.grey, colours.black)
end

-- Paints the user interface by reading the state.
-- If no events of any kind were handled, no need for this.
local function paint_ui(state)
    ui:fill_label("Messenger 1.0", colours.white, colours.lightBlue, 1, 1, ui.w, "center")
    text_area:render(ui)
    ui:fill_label(">" .. state.input_buffer, colours.white, colours.grey, 1, ui.h, ui.w, "left")
    ui:render()
end

local function handle_main(state)
    local data = {os.pullEvent()}
    local ev = data[1]
    local repaint = true
    if ev == 'mouse_scroll' then -- Future feature
        state.scroll = state.scroll + data[2]
    elseif ev == 'key' then
        if data[2] == keys.backspace and #state.input_buffer >= 1 then
            state.input_buffer = state.input_buffer:sub(1, #state.input_buffer-1)
        elseif data[2] == keys.leftCtrl then
            return true
        elseif data[2] == keys.enter and #state.input_buffer > 0 then
            local msg = state.input_buffer
            state.input_buffer = ''
            send { action = 'message', data = msg }
            text_area:add_message('$3' .. settings.get('messenger.nick') .. '$8 ' .. msg)
        end
    elseif ev == 'char' then
        state.input_buffer = state.input_buffer .. data[2]
    else
        repaint = false
    end
    if repaint then paint_ui(state) end
    return false
end

-- TODO
local function handle_scroll(state)
    return function(_, dir)
        state.scroll = state.scroll + dir
    end
end

local function should_repaint()
    os.queueEvent('repaint')
end

local function handle_key(state)
    return function(_, key)
        if key == keys.backspace and #state.input_buffer >= 1 then
            state.input_buffer = state.input_buffer:sub(1, #state.input_buffer-1)
            should_repaint()
        elseif key == keys.leftCtrl then
            return true
        elseif key == keys.enter and #state.input_buffer > 0 then
            local msg = state.input_buffer
            state.input_buffer = ''
            send { action = 'message', data = msg }
            text_area:add_message('$3' .. settings.get('messenger.nick') .. '$8 ' .. msg)
            should_repaint()
        end
    end
end

local function handle_char(state)
    return function(_, char)
        state.input_buffer = state.input_buffer .. char
        should_repaint()
    end
end

local function handle_repaint(state)
    return function()
        paint_ui(state)
    end
end

local function handle_rednet(state)
    return function(_, sender, msg)
        -- Drop messages that are not from the server.
        if sender ~= host_id then return end
        if msg.event == 'new_client' then
            print_system_msg(tostring(msg.nick) .. ' joined')
        elseif msg.event == 'client_dropped' then
            print_system_msg(tostring(msg.nick) .. ' left')
        elseif msg.event == 'message' then
            text_area:add_message('$b' .. msg.nick .. '$0 ' .. msg.message)
        else
            print_system_msg('Unknown netmsg "' .. tostring(msg.event) .. '"')
        end
        should_repaint()
    end
end

local function main()
    term.setCursorBlink(false)
    term.clear()
    term.setCursorPos(1, 1)
    print('Connecting to server...')
    if not connect(server_name()) then return end
    print('Downloading messages...')
    if not download_messages() then return printError('Could not fetch messages from the server.') end
    print('Ok')
    sleep(0.25)
    local state = {
        scroll = 1,
        overflow = 0,
        input_buffer = ''
    }
    print_system_msg('Connected as ' .. settings.get('messenger.nick'))
    paint_ui(state)
    nucleic.loop {
        rednet_message = handle_rednet(state),
        mouse_scroll = handle_scroll(state),
        key = handle_key(state),
        char = handle_char(state),
        repaint = handle_repaint(state)
    }
    send({ action = 'disconnect' })
    term.clear()
    term.setCursorPos(1, 1)
    print('Bye!')
end

main()

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

-- Parser for SNAP cfg files

local cfg = {}

local EOF = setmetatable({}, {
    __tostring = function() return 'EOF' end
})

local function set_of(array)
    local set = {}
    for _, v in ipairs(array) do
        set[v] = true
    end
    return set
end

local new = {}

function new:Set(...)
    return set_of {...}
end

-- Map the palette to a vector space so we can find the nearest.
local palette = {
    colours.white,
    colours.orange,
    colours.magenta,
    colours.lightBlue,
    colours.yellow,
    colours.lime,
    colours.pink,
    colours.gray,
    colours.lightGray,
    colours.cyan,
    colours.purple,
    colours.blue,
    colours.brown,
    colours.green,
    colours.red,
    colours.black,
}
local colour_map = {}
for k, v in ipairs(palette) do
    colour_map[k] = { term.nativePaletteColour(v) }
end
-- Euclidean distance of two vectors
local function euclid(a, b)
    return math.sqrt(
        math.pow(b[1] - a[1], 2),
        math.pow(b[2] - a[2], 2),
        math.pow(b[3] - a[3], 2)
    )
end
local function find_nearest(...)
    local col = {...}
    local last_k
    local last_dist = 1000000
    for k, v in ipairs(colour_map) do
        local dist = euclid(col, v)
        if last_dist > dist then
            last_k = k
            last_dist = dist
        end
    end
    return palette[last_k]
end

local function parse_colour(raw)
    if #raw == 2 then -- Parse blit
        return colours.fromBlit(raw:sub(2, 2):lower())
    else
        local r = tonumber('0x' .. raw:sub(2, 3)) / 255.0
        local g = tonumber('0x' .. raw:sub(4, 5)) / 255.0
        local b = tonumber('0x' .. raw:sub(6, 7)) / 255.0
        return { colour = find_nearest(r, g, b), raw = {r, g, b}, is_color = true }
    end
end

function cfg.parse(raw)
    -- State machine
    local i = 1
    local len = #raw
    -- Navigation and matching
    local function current_line()
        local lines = 1
        for _ in raw:sub(1, i):gmatch('\n') do
            lines = lines + 1
        end
        return lines
    end
    local function current()
        if i >= len then return EOF end
        return raw:sub(i, i)
    end
    local function next(amount)
        i = i + (amount or 1)
        return current()
    end
    local function match(str)
        local ch = current()
        if ch == EOF then return false end
        return ch:find(str) ~= nil
    end
    local function seek_until(...)
        local chars = new: Set(...)
        local buffer = ''
        repeat
            local n = next()
            if n == EOF then
                return buffer
            end
            buffer = buffer .. n
        until chars[current()]
        return buffer
    end
    local function match_ahead(str, consume)
        local info = {raw:find(str, i)}
        if #info == 0 then return nil end
        local from = table.remove(info, 1)
        local to = table.remove(info, 1)
        if consume then
            i = to + 1
        end
        info[#info+1] = raw:sub(from, to)
        return info
    end
    -- Parsing
    local info = {}
    local errors
    local function push_error(msg)
        errors = msg
        return nil, msg
    end
    local function syntax_error(message)
        local f = raw:find('\n', i) or len
        local line = tostring(current_line())
        local s = raw:sub(i, f)
        local pipe = string.char(149)
        return push_error((message or 'I don\'t know what to do with this, Malcom:')
            .. '\n ' .. (' '):rep(#line) .. pipe
            .. '\n ' .. line .. pipe .. s:gsub('\n', '')
            .. '\n ' .. (' '):rep(#line) .. pipe .. ('~'):rep(#s))
    end
    local function parse_value(info, key)
        match_ahead(' *', true) -- Skip spaces
        local open_str = match_ahead('^["\']')
        if open_str then -- Parse string!
            open_str = open_str[1]
            next()
            local value = ''
            while true do
                local n = match_ahead('^(\\' .. open_str .. ')')
                if n then
                    value = value .. n[1]
                    next(2) -- Skip the two tokens
                elseif current() == open_str then
                    next()
                    break
                else
                    local ne = current()
                    if ne == EOF then
                        return syntax_error('Non closed string found, you may be missing a ' .. open_str .. ' somewhere')
                    end
                    value = value .. ne
                    next()
                end
            end
            info[key] = value
        else
            local value = match_ahead('^(.-)\n', true)
            if value == nil then
                next()
                return true
            end
            value = value[1]
            local n = tonumber(value)
            if n ~= nil then
                info[key] = n
            elseif value == 'yes' or value == 'true' or value == 'on' or value == 'high' then
                info[key] = true
            elseif value == 'no' or value == 'false' or value == 'off' or value == 'low' then
                info[key] = false
            elseif value:find('^#[A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9]$') or value:find('^#[0-9A-Fa-f]') then
                info[key] = parse_colour(value)
            else
                info[key] = value
            end
        end
    end
    local function parse_kv()
        local key = match_ahead('^([^;]-)=', true)
        if key == nil then
            return syntax_error()
        end
        key = key[1]
        parse_value(info, key)
    end
    local function parse_array()
        local key = match_ahead('^%[(.-)%]%s*', true)
        key = key[1]
        local value = {}
        while true do
            if match_ahead('^%s*%[') or match_ahead('^%s*[^\n]+=') then
                break
            end
            local room = {}
            if parse_value(room, 'out') then break end
            value[#value+1] = room.out
        end
        info[key] = value
    end
    repeat
        if errors ~= nil then
            return nil, errors
        end
        if match(';') then
            seek_until('\n') -- Discard comments
        elseif match('%s') then
            next() -- Ignore blanks at root!
        elseif match('[^%s%[]') then
            parse_kv()
        elseif match('%[') then
            parse_array()
        else
            return syntax_error()
        end
    until current() == EOF
    return info
end

return cfg

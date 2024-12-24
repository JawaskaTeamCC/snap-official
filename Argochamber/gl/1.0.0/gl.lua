-- A simple buffer abstraction for rapid graphics painting
-- Via buffer swapping and the BLIT api.
-- Argochamber Interactive 2024
-- MIT License
local class = require 'class'

local gl = {}

local Buffer = class()
gl.Buffer = Buffer

function Buffer:constructor(w, h)
    self.w = w
    self.h = h
    self.text_buffer = {}
    self.fg_buffer = {}
    self.bg_buffer = {}
    self:resize_buffer()
end

function Buffer:resize_buffer()
    for i=1, self.h do
        local text_row = {}
        local fg_row = {}
        local bg_row = {}
        for i=1, self.w do
            text_row[i] = ' '
            fg_row[i] = '0'
            bg_row[i] = 'f'
        end
        self.text_buffer[i] = text_row
        self.fg_buffer[i] = fg_row
        self.bg_buffer[i] = bg_row
    end
end

function Buffer:swap()
    for i=1, self.h do
        term.setCursorPos(1, i)
        term.blit(
            table.concat(self.text_buffer[i], ''),
            table.concat(self.fg_buffer[i], ''),
            table.concat(self.bg_buffer[i], '')
        )
    end
end

function Buffer:set_at(x, y, text, fg, bg)
    if not x or not y then return false end
    if x < 0 or x > self.w or y < 0 or y > self.h then return false end
    if text then
        self.text_buffer[y][x] = text:sub(1,1)
    end
    if fg then
        self.fg_buffer[y][x] = fg:sub(1,1)
    end
    if bg then
        self.bg_buffer[y][x] = bg:sub(1,1)
    end
    self:set_print_cursor(x, y)
    return true
end

function Buffer:print_at(x, y, text, fg, bg)
    local start_x, start_y = x, y
    for i=1, #text do
        local ch = text:sub(i, i)
        if ch == '\n' then -- respect line breaks
            y = y + 1
            x = start_x
        else
            local _fg, _bg
            if fg then _fg = fg:sub(i, i) end
            if bg then _bg = bg:sub(i, i) end
            self:set_at(x, y, ch, _fg, _bg)
            x = x + 1
            if x > self.w then
                x = start_x
                y = y + 1
            end
        end
        if y > self.h then
            break -- Stop printing if overflowing.
        end
    end
    self:set_print_cursor(x, y)
end

function Buffer:set_print_cursor(x, y)
    self._last_print_cursor = { x, y }
end

function Buffer:print(text, fg, bg)
    local x, y = 1, 1
    if self._last_print_cursor then
        x = self._last_print_cursor[1]
        y = self._last_print_cursor[2]
    end
    return self:print_at(x, y, text, fg, bg)
end

function Buffer:printf(...)
    local last_fg = '0'
    local last_bg = 'f'
    for _, part in ipairs {...} do
        if type(part) == 'table' then
            if part.bg then
                if type(part.bg) == 'number' then
                    last_bg = colours.toBlit(part.bg)
                else
                    last_bg = part.bg
                end
            end
            if part.fg then
                if type(part.fg) == 'number' then
                    last_fg = colours.toBlit(part.fg)
                else
                    last_fg = part.fg
                end
            end
            local text = part.text or part[1]
            if text then
                self:print(text, last_fg:rep(#text), last_bg:rep(#text))
            end
        else
            self:print(tostring(part))
        end
    end
end

function gl.create_buffer(w, h)
    local scr_w, scr_h = term.getSize()
    return gl.Buffer(w or scr_w, h or scr_h)
end

return gl

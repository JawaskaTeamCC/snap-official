-- MIT License
-- Copyright (c) 2024 Argochamber Interactive
--
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

local class = require 'class'

local gl = {}

function gl.to_blit(input)
    if type(input) == 'number' then
        return colours.toBlit(input)
    else
        return tostring(input or '0')
    end
end

--- Buffer class for managing and rendering graphical buffers.
local Buffer = class()

--- Constructor for the Buffer class.
-- @param w Width of the buffer.
-- @param h Height of the buffer.
function Buffer:constructor(w, h)
    self.w = w
    self.h = h
    self.cursor = { x = 1, y = 1 }
    self:clear()
end

--- Resizes the buffer dynamically.
-- @param new_w New width of the buffer.
-- @param new_h New height of the buffer.
function Buffer:resize(new_w, new_h)
    local new_chars, new_fg_colors, new_bg_colors = {}, {}, {}
    for i = 1, new_h do
        new_chars[i] = {}
        new_fg_colors[i] = {}
        new_bg_colors[i] = {}
        for j = 1, new_w do
            if i <= self.h and j <= self.w then
                new_chars[i][j] = self.chars[i][j]
                new_fg_colors[i][j] = self.fg_colors[i][j]
                new_bg_colors[i][j] = self.bg_colors[i][j]
            else
                new_chars[i][j] = " "
                new_fg_colors[i][j] = "0"
                new_bg_colors[i][j] = "f"
            end
        end
    end
    self.chars, self.fg_colors, self.bg_colors = new_chars, new_fg_colors, new_bg_colors
    self.w, self.h = new_w, new_h
end

--- Sets the cursor position in the buffer.
-- @param x X-coordinate.
-- @param y Y-coordinate.
function Buffer:set_cursor(x, y)
    self.cursor.x = x
    self.cursor.y = y
end

--- Copies a section of one buffer to another.
-- @param target Target buffer.
-- @param src_x Source X-coordinate (1-based).
-- @param src_y Source Y-coordinate (1-based).
-- @param target_x Target X-coordinate (1-based).
-- @param target_y Target Y-coordinate (1-based).
-- @param w Width of the region to copy.
-- @param h Height of the region to copy.
function Buffer:copy_to(target, src_x, src_y, target_x, target_y, w, h)
    for i = 0, h - 1 do
        for j = 0, w - 1 do
            local sx, sy = src_x + j, src_y + i
            local tx, ty = target_x + j, target_y + i
            if sx >= 1 and sx <= self.w and sy >= 1 and sy <= self.h and
               tx >= 1 and tx <= target.w and ty >= 1 and ty <= target.h then
                target.chars[ty][tx] = self.chars[sy][sx]
                target.fg_colors[ty][tx] = self.fg_colors[sy][sx]
                target.bg_colors[ty][tx] = self.bg_colors[sy][sx]
            end
        end
    end
end

--- Swaps the contents of two buffers.
-- @param other The other buffer to swap with.
function Buffer:swap(other)
    self.chars, other.chars = other.chars, self.chars
    self.fg_colors, other.fg_colors = other.fg_colors, self.fg_colors
    self.bg_colors, other.bg_colors = other.bg_colors, self.bg_colors
    self.w, other.w = other.w, self.w
    self.h, other.h = other.h, self.h
end

--- Clears the entire buffer to a specific character and colors.
-- @param char Character to fill with (default is space).
-- @param fg Foreground color (default is "0").
-- @param bg Background color (default is "f").
function Buffer:clear(char, fg, bg)
    char = gl.to_blit(char or " ")
    fg = gl.to_blit(fg or "0")
    bg = gl.to_blit(bg or "f")
    self.chars, self.fg_colors, self.bg_colors = {}, {}, {}
    for i = 1, self.h do
        self.chars[i] = {}
        self.fg_colors[i] = {}
        self.bg_colors[i] = {}
        for j = 1, self.w do
            self.chars[i][j] = char
            self.fg_colors[i][j] = fg
            self.bg_colors[i][j] = bg
        end
    end
end

--- Sets a character at a specific position in the buffer.
-- @param x X-coordinate (1-based).
-- @param y Y-coordinate (1-based).
-- @param char Character to set.
-- @param fg Foreground color (optional).
-- @param bg Background color (optional).
function Buffer:set_char(x, y, char, fg, bg)
    if x >= 1 and x <= self.w and y >= 1 and y <= self.h then
        self.chars[y][x] = gl.to_blit(char)
        if fg then self.fg_colors[y][x] = gl.to_blit(fg) end
        if bg then self.bg_colors[y][x] = gl.to_blit(bg) end
    end
end

--- Fills a rectangular area in the buffer with a specific character and colors.
-- @param x X-coordinate of the top-left corner (1-based).
-- @param y Y-coordinate of the top-left corner (1-based).
-- @param w Width of the rectangle.
-- @param h Height of the rectangle.
-- @param char Character to fill with.
-- @param fg Foreground color (optional).
-- @param bg Background color (optional).
function Buffer:fill_rectangle(x, y, w, h, char, fg, bg)
    for i = y, y + h - 1 do
        for j = x, x + w - 1 do
            self:set_char(j, i, char, fg, bg)
        end
    end
end

function Buffer:fill_label(text, fg, bg, x, y, width, alignment)
    if #text > width then
        text = text:sub(1, width)
    end
    local start_x
    if alignment == "center" then
        start_x = x + math.floor((width - #text) / 2)
    elseif alignment == "right" then
        start_x = x + width - #text
    else -- Default to left alignment.
        start_x = x
    end
    self:fill_rectangle(x, y, width, 1, " ", nil, bg)
    for i = 1, #text do
        self:set_char(start_x + i - 1, y, text:sub(i, i), fg, bg)
    end
end

function Buffer:render()
    for i = 1, self.h do
        term.setCursorPos(1, i)
        term.blit(
            table.concat(self.chars[i], ''),
            table.concat(self.fg_colors[i], ''),
            table.concat(self.bg_colors[i], '')
        )
    end
end

--- Creates a new buffer.
-- @param w Width of the buffer.
-- @param h Height of the buffer.
-- @return A new Buffer instance.
function gl.create_buffer(w, h)
    local scr_w, scr_h = term.getSize()
    return gl.Buffer(w or scr_w, h or scr_h)
end

gl.Buffer = Buffer

--- Enhanced TextArea class with target buffer rendering.
local TextArea = class()

--- Constructor for the TextArea class.
-- @param x X-coordinate of the top-left corner.
-- @param y Y-coordinate of the top-left corner.
-- @param w Width of the text area.
-- @param h Height of the text area.
function TextArea:constructor(x, y, w, h)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.lines = {}
    self.scroll_offset = 0
end

--- Adds a message to the text area.
-- @param text The text of the message.
-- @param fg Foreground color string.
-- @param bg Background color string.
function TextArea:add_message(text, fg, bg)
    if not bg and not fg then
        fg = ''
        bg = ''
        local last_fg = colours.toBlit(colours.white)
        local last_bg = colours.toBlit(colours.black)
        local parsed = ''
        local function push(t, f, b)
            if f then last_fg = f end
            if b then last_bg = b end
            if t then
                parsed = parsed .. t
                fg = fg .. last_fg
                bg = bg .. last_bg
            end
        end
        local i = 1
        local function get(j)
            return text:sub(i + (j or 0), i + (j or 0))
        end
        repeat
            if get() == '$' then
                if get(1) == '$' then
                    push('$')
                    i = i + 1
                elseif get(1):find('^[A-Fa-f0-9]$') then
                    push(nil, get(1))
                    i = i + 1
                else
                    push(get())
                end
            elseif get() == '%' then
                if get(1) == '%' then
                    push('%')
                    i = i + 1
                elseif get(1):find('^[A-Fa-f0-9]$') then
                    push(nil, nil, get(1))
                    i = i + 1
                else
                    push(get())
                end
            else
                push(get())
            end
            i = i + 1
        until i > #text
        text = parsed
    else
        fg = gl.to_blit(fg or colours.white):rep(#text)
        bg = gl.to_blit(bg or colours.black):rep(#text)
    end
    local wrapped_lines = self:wrap_text(text)
    local j = 1
    for i, line in ipairs(wrapped_lines) do
        local fg_line = ''
        local bg_line = ''
        for x=j, j + (#line - 1) do
            fg_line = fg_line .. fg:sub(x, x)
            bg_line = bg_line .. bg:sub(x, x)
        end
        j = j + #line
        -- if sus then
        --     print(i)
        --     print(line)
        --     print(fg_line)
        --     print(bg_line)
        -- end
        table.insert(self.lines, { text = line, fg = fg_line, bg = bg_line })
    end
    -- if sus then
    --     error()
    -- end
    self:trim_lines()
    -- sus = not sus
end

--- Wraps text into lines that fit within the text area width.
-- @param text The text to wrap.
-- @return A table of wrapped lines.
function TextArea:wrap_text(text)
    local wrapped = {}
    local line = ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > self.w then
            table.insert(wrapped, line)
            line = word
        else
            if #line > 0 then
                line = line .. " " .. word
            else
                line = word
            end
        end
    end
    if #line > 0 then
        table.insert(wrapped, line)
    end
    return wrapped
end

--- Trims excess lines to fit within the text area's height.
function TextArea:trim_lines()
    while #self.lines > self.h do
        table.remove(self.lines, 1)
    end
end

--- Renders the text area on a specified buffer.
-- @param target Target buffer for rendering.
function TextArea:render(target)
    for i = 1, self.h do
        local line_index = i + self.scroll_offset
        local line = self.lines[line_index]
        if line then
            target:fill_rectangle(self.x, self.y + i - 1, self.w, 1, " ", nil, nil)
            for j = 1, #line.text do
                target:set_char(self.x + j - 1, self.y + i - 1, line.text:sub(j, j), line.fg:sub(j, j), line.bg:sub(j, j))
            end
        else
            target:fill_rectangle(self.x, self.y + i - 1, self.w, 1, " ", nil, nil)
        end
    end
end

gl.TextArea = TextArea

return gl

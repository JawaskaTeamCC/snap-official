-- Calc
local gl = require 'gl'
local class = require 'class'

local APP_VERSION = '1.0'

local SAILS_PER_SU_PER_RPM = {
    { { 8, 15 }, 512, 1 },
    { { 16, 23 }, 1024, 2 },
    { { 24, 31 }, 1536, 3 },
    { { 32, 39 }, 2048, 4 },
    { { 40, 47 }, 2560, 5 },
    { { 48, 55 }, 3072, 6 },
    { { 56, 63 }, 3584, 7 },
    { { 64, 71 }, 4096, 8 },
    { { 72, 79 }, 4608, 9 },
    { { 80, 87 }, 5120, 10 },
    { { 88, 95 }, 5632, 11 },
    { { 96, 103 }, 6144, 12 },
    { { 104, 111 }, 6656, 13 },
    { { 112, 119 }, 7168, 14 },
    { { 120, 127 }, 7680, 15 },
    { { 128, 999 }, 8192, 16 }
}

local STATOR_BASE_SU = {
    36,
    48,
    72,
    120,
    312
}
local STATOR_TYPES = {
    'Magnetite',
    'Redstone',
    'Layered',
    'Fluxuated',
    'Netherite'
}
local STATOR_COLOURS = {
    colours.black,
    colours.red,
    colours.yellow,
    colours.blue,
    colours.cyan
}

local App = class()

function App:constructor()
    self.buf = gl.create_buffer()
    self.stator = 1
    self.coils = 1
    self.input_level = 1
    self.sail_base_rpm = 1
    self.sail_base_su = 1
    self.coil_power = 1
    self.max_target_rpm = 1
    self.is_valid = true
end

function App:recalculate_output()
    local sails = SAILS_PER_SU_PER_RPM[self.input_level]
    local base_stress = self.coils * STATOR_BASE_SU[self.stator]
    self.coil_power = base_stress
    self.sail_base_rpm = sails[3]
    self.max_target_rpm = self.sail_base_rpm
    self.sail_base_su = sails[2]
    local base_power = self.sail_base_rpm * self.sail_base_su
    local needed_power = base_stress * self.sail_base_rpm
    self.is_valid = base_power >= needed_power
    if self.is_valid then
        for i=self.sail_base_rpm, 256 do
            local need_p = i * base_stress
            if need_p > self.sail_base_su then
                return
            end
            self.max_target_rpm = i
        end
        self.max_target_rpm = 256
    else
        self.max_target_rpm = '-'
    end
end

function App:_paint_handles(y)
    self.buf:set_char(1, y, string.char(17), colours.white, colours.grey)
    self.buf:set_char(self.buf.w, y, string.char(16), colours.white, colours.grey)
end

function App:paint_ui()
    self.buf:clear(nil, colours.white, colours.grey)
    self.buf:fill_label('Energon ' .. APP_VERSION, colours.white, colours.lightBlue, 1, 1, self.buf.w, 'center')
    self.buf:set_char(self.buf.w, 1, string.char(215), colours.white, colours.red)
    self.buf:set_char(self.buf.w - 1, 1, string.char(149), colours.lightBlue, colours.red)
    self.buf:fill_label('Materials:', colours.white, colours.lightGrey, 1, 3, self.buf.w, 'left')
    self.buf:fill_label(STATOR_TYPES[self.stator], STATOR_COLOURS[self.stator], colours.grey, 1, 5, self.buf.w, 'center')
    self:_paint_handles(5)
    self.buf:fill_label('x' .. self.coils .. ' Coils', colours.lightGrey, colours.grey, 1, 6, self.buf.w, 'center')
    self:_paint_handles(6)
    local sails = SAILS_PER_SU_PER_RPM[self.input_level]
    self.buf:fill_label(sails[1][1] .. '-' .. sails[1][2] .. ' sails', colours.lightGrey, colours.grey, 1, 7, self.buf.w, 'center')
    self:_paint_handles(7)
    self.buf:fill_label('Windmill:', colours.white, colours.lightGrey, 1, 9, self.buf.w, 'left')
    self.buf:fill_label('base ' .. self.sail_base_rpm .. ' rpm', colours.lightGrey, colours.grey, 1, 11, self.buf.w, 'center')
    self.buf:fill_label('base ' .. self.sail_base_su .. ' su', colours.lightGrey, colours.grey, 1, 12, self.buf.w, 'center')
    self.buf:fill_label('Generator:', colours.white, colours.lightGrey, 1, 14, self.buf.w, 'left')
    self.buf:fill_label('coil ' .. self.coil_power .. ' su*rpm', colours.lightGrey, colours.grey, 1, 16, self.buf.w, 'center')
    self.buf:fill_label('max target rpm: ' .. self.max_target_rpm, colours.lightGrey, colours.grey, 1, 17, self.buf.w, 'center')
    if self.is_valid then
        self.buf:fill_label('Valid setup', colours.lime, colours.grey, 1, 19, self.buf.w, 'center')
    else
        self.buf:fill_label(string.char(19) .. ' INVALID SETUP ' .. string.char(19), colours.red, colours.grey, 1, 19, self.buf.w, 'center')
    end
    self.buf:render()
end

function App:handle_keys()
    while true do
        local _, key = os.pullEvent('key')
    end
end

function App:handle_mouse()
    while true do
        local _, button, x, y = os.pullEvent('mouse_click')
        if button == 1 then
            if x == self.buf.w and y == 1 then
                return false
            elseif x == self.buf.w and y == 5  then
                self.stator = self.stator + 1
                if self.stator > #STATOR_TYPES then self.stator = 1 end
                self:repaint()
            elseif x == 1 and y == 5 then
                self.stator = self.stator - 1
                if self.stator <= 0 then self.stator = #STATOR_TYPES end
                self:repaint()
            elseif x == 1 and y == 6 then
                self.coils = self.coils - 1
                if self.coils <= 0 then self.coils = 1 end
                self:repaint()
            elseif x == self.buf.w and y == 6 then
                self.coils = self.coils + 1
                if self.coils > 16 then self.coils = 16 end
                self:repaint()
            elseif x == 1 and y == 7 then
                self.input_level = self.input_level - 1
                if self.input_level <= 0 then self.input_level = 1 end
                self:repaint()
            elseif x == self.buf.w and y == 7 then
                self.input_level = self.input_level + 1
                if self.input_level > #SAILS_PER_SU_PER_RPM then self.input_level = #SAILS_PER_SU_PER_RPM end
                self:repaint()
            end
        end
    end
end

function App:handle_repaint()
    while true do
        local _ = os.pullEvent('repaint')
        self:paint_ui()
    end
end

function App:repaint()
    self:recalculate_output()
    os.queueEvent('repaint')
end

function App:run()
    self:repaint()
    parallel.waitForAny(
        function() return self:handle_keys() end,
        function() return self:handle_mouse() end,
        function() return self:handle_repaint() end
    )
end

function App:restore_state(file)
    local data = textutils.unserialiseJSON(file:read('*all'))
    for k, v in pairs(data) do
        self[k] = v
    end
end

function App:store_state()
    local store = {
        stator = self.stator,
        coils = self.coils,
        input_level = self.input_level
    }
    local f = io.open('.energdb', 'w')
    f:write(textutils.serialiseJSON(store))
    f:close()
end

local app = App()

local f = io.open('.energdb', 'r')
if f then
    app:restore_state(f)
    app:recalculate_output()
    f:close()
end

app:run()
app:store_state()
term.setCursorPos(1, 1)
term.clear()
print('Bye!')
print('Energon ' .. APP_VERSION)
print(' by Argochamber')

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

local function Callable(tbl, callback)
    local meta = getmetatable(tbl) or {}
    meta.__call = callback
    return setmetatable(tbl, meta)
end

local class = Callable({ by_name = {}, name_by_class = {} }, function(class, name, base)
    local this_class = { base }
    if name then
        class.by_name[name] = this_class
        class.name_by_class[this_class] = name
    end
    return setmetatable(this_class, {
        is_class = true,
        __call = function(_, ...)
            local new = class.set_prototype_of({}, this_class)
            if new.constructor then new.constructor(new, ...) end
            return new
        end,
        __tostring = function()
            return 'class ' .. tostring(name or '<anonymous>')
        end
    })
end)

class.Callable = Callable

function class.get_class_of(object)
    return rawget(object, '__prototype__')
end

function class.get_class_name(object)
    local class_ref = class.get_class_of(object)
    if not class_ref then return nil end
    return class.name_by_class[class_ref]
end

function class.get_class_by_name(name)
    return class.by_name[name]
end

function class.set_prototype_of(object, prototype)
    object.__prototype__ = prototype
    local meta = {}
    for k, v in pairs(prototype) do
        if k:sub(1, 2) == '__' then
            meta[k] = v
        end
    end
    function meta.get_class() return prototype end
    function meta:__index(k)
        if rawget(self, k) ~= nil then return rawget(self, k) end
        if prototype[k] ~= nil then return prototype[k] end
        if prototype.base ~= nil then return prototype.base[k] end
    end
    return setmetatable(object, meta)
end

function class.is_class(obj)
    if type(obj) == 'table' then
        local meta = getmetatable(obj)
        if not meta then return false end
        if meta.is_class then return true end
    end
    return false
end

return class

-- Simple rust's result library
local class = require 'class'

local lib = {}

local Ok = class()
lib.Ok = Ok

function Ok:constructor(value)
    self.value = value
end

function Ok:unwrap()
    return self.value
end

function Ok:is_ok()
    return true
end

function Ok:is_err()
    return false
end

function Ok:unwrap_err()
    return error('Attempting to unwrap error of Ok value')
end

local Err = class()

function Err:constructor(err)
    self.error = err
end

function Err:unwrap()
    return error('Attempting to unwrap error value:', self.error)
end

function Err:unwrap_err()
    return self.error
end

function Err:is_ok()
    return false
end

function Err:is_err()
    return true
end

return lib

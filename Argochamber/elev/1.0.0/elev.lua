-- Controls the elevator
-- Uppon summoning, will
-- toggle the direction
-- of the pulley.

local COM_PROTOCOL = 'elevon'
local MODEM_SIDE   = 'back'

function send(cmd)
    rednet.broadcast(cmd, COM_PROTOCOL)
end

rednet.open(MODEM_SIDE)

send 'toggle'

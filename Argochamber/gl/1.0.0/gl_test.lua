local gl = require 'gl'

local buf = gl.create_buffer()

buf:set_at(2, 2, 'A', '5', 'f')
buf:set_at(2, 3, 'B', '6', 'f')
buf:printf({ '<Dr. Breen> ', fg = colours.blue }, { 'Hey Freeman', fg = colours.red })
buf:swap()
io.read('*line')

-- Simple web based installer
local req = http.get('https://raw.githubusercontent.com/JawaskaTeamCC/snap-official/refs/heads/main/Argochamber/snap/1.0.0/snap.lua')
local fout = io.open('snap.lua', 'w')
fout:write(req.readAll())
req.close()
fout:close()
req = nil
fout = nil

req = http.get('https://raw.githubusercontent.com/JawaskaTeamCC/snap-official/refs/heads/main/Argochamber/cfg-parser/1.0.0/cfg-parser.lua')
fout:write(req.readAll())
req.close()
fout:close()
print('Done')

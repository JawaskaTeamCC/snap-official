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

-- SNAP command utility
-- Install programs without headaches

settings.define('snap.repo', {
    description = 'The software repository where it will look for programs and libraries.',
    default = 'https://raw.githubusercontent.com/JawaskaTeamCC/snap-official',
    type = 'string'
})
settings.define('snap.branch', {
    description = 'The repository branch to use',
    default = 'main',
    type = 'string'
})

local function compose_url(resource)
    return settings.get('snap.repo'):gsub('/*$', '') .. '/refs/heads/' .. settings.get('snap.branch') .. '/' .. resource:gsub('^/*', '')
end

local function get_resource(resource)
    local req = http.get(compose_url(resource))
    if req == nil then return nil end
    local data = req.readAll()
    req.close()
    return data
end

local cfg = require 'cfg-parser'
local function get_cfg(resource)
    local res = get_resource(resource)
    if res == nil then return nil end
    return cfg.parse(res)
end

local function update_database()
    local db = {
        organizations = {},
        projects = {}
    }
    local grp = get_cfg('info.cfg')
    for _, v in ipairs(grp.public) do
        print(' Fetching organization ' .. v .. '...')
        local info = get_cfg(v .. '/info.cfg')
        local data = {
            name = v,
            projects = {}
        }
        for _, v in ipairs(info.public) do
            print('  Retrieving ' .. v .. ' metadata...')
            local info = get_cfg(data.name .. '/' .. v .. '/project.cfg')
            local proj = {
                name = v,
                versions = info.versions,
                latest = info.latest,
                organization = data.name
            }
            db.projects[#db.projects+1] = proj
            data.projects[proj.name] = proj
        end
        db.organizations[data.name] = data
    end
    local f = io.open('.snapdb', 'w')
    f:write(textutils.serialiseJSON(db, { allow_repetitions = true }))
    f:close()
    return db
end

local function parse_target(name)
    if name:find('^[^@]+@[^%^]+^.+$') then
        local _, _, org, target, version = name:find('^([^@]+)@([^%^]+)^(.+)$')
        return org, target, version
    elseif name:find('^[^@]+@[^%^]+$') then
        local _, _, org, target = name:find('^([^@]+)@([^%^]+)$')
        return org, target, nil
    elseif name:find('^[^%^]+^.+$') then
        local _, _, target, version = name:find('^[^%^]+^.+$')
        return nil, target, version
    else
        return nil, name, nil
    end
end

local db_cache

local function try_install(org, target, version)
    if not target then
        return printError('Target parameter is mandatory for try_install(...)!')
    end
    print('Installing ' .. target)
    if not org then
        for _, v in ipairs(db_cache.projects) do
            if v.name == target then
                org = v.organization
                break
            end
        end
        if not org then
            return printError('Target ' .. target .. ' not found.')
        end
    end
    if not version then
        local db_org = db_cache.organizations[org]
        if not db_org then
            return printError('Organization ' .. org .. ' database entry contains no information.')
        end
        local info = db_org.projects[target]
        if not info then
            return printError('Target ' .. target .. ' found for organization ' .. org .. ' but the metadata is missing.')
        end
        version = info.latest
        if not version then
            print(' WARNING: Target ' .. target .. ' has not set a latest version')
            version = info.versions[1]
        end
        if not version then
            return printError('Version list for target ' .. target .. ' is empty!')
        end
    end
    local install_info = get_cfg(org .. '/' .. target .. '/' .. version .. '/install.cfg')
    if not install_info then
        return printError('Can\'t install ' .. target .. ' v' .. version .. ': install.cfg file not found on the repo.')
    end
    if not install_info.files or #install_info.files == 0 then
        return printError('No files found for installation')
    end
    print('Resolving dependencies...')
    for _, dep in ipairs(install_info.dependencies or {}) do
        local org, target, version = parse_target(dep)
        try_install(org, target, version)
    end
    print('Unpacking files...')
    for _, f in ipairs(install_info.files) do
        local raw = get_resource(org .. '/' .. target .. '/' .. version .. '/' .. f)
        local fout = io.open(f, 'w')
        fout:write(raw)
        fout:close()
    end
end

local function do_install(programs)
    if #programs == 0 then
        return printError('Must specify at least one program!')
    end
    local fdb = io.open('.snapdb', 'r')
    if fdb == nil then
        return printError('Run snap update first! (No database found)')
    end
    db_cache = textutils.unserialiseJSON(fdb:read('*all'))
    fdb:close()
    for _, v in ipairs(programs) do
        local org, target, version = parse_target(v)
        try_install(org, target, version)
    end
end

local args = {...}

if args[1] == 'update' then
    print('Updating database...')
    update_database()
    print('Done!')
elseif args[1] == 'install' then
    table.remove(args, 1)
    do_install(args)
elseif args[1] == 'help' then
    print [[Snap v1.0 ~ Argochamber Interactive

Usage: snap <subcommand>
    Where subcommand is one of:
    - help
    - update
    - install <program>

    Examples of install syntax:
    snap install org@prog
    snap install prog^1.0
    snap install prog
    snap install org@prog^1.0]]
else
    printError('Bad usage! run "snap help"')
end

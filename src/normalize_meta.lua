--[[
    normalize_meta

    Normalize metadata options for collection
]]
local log = require('log')
local type = pandoc.utils.type
local stringify = pandoc.utils.stringify

--- syntactic_sugar: normalize alias keys in meta
-- in case of duplicates we warn the user and
-- use the ones with more explicit names.
-- if `collection` or `offprints` are strings
-- we assume they're defaults filepaths.
local function normalize_meta(meta)

    -- function that converts aliases to official fields in a map
    -- following an alias table. 
    -- The map could be the doc's Meta or a MetaMap within it. 
    -- Use `root` to let the user know what the root key was in the 
    -- later case in error messages, e.g. "imports[1]/". 
    -- Merging behaviour: if the official already exists we warn the
    -- user and simply ignore the alias key.
    -- Warning: aliases must be acceptable Lua map keys, so they can't
    --  contain e.g. dashes. Official names aren't restricted.
    -- @alias_table table an alias map aliasname = officialname. 
    -- @root string names the root for error messages, e.g. "imports[1]/"
    -- @map Meta or MetaMap to be cleaned up
    function make_official(alias_table, root, map)
        if type(map) == 'table' or type(map) == 'Meta' then
            for alias,official in pairs(alias_table) do
                if map[alias] and map[official] then
                    log('WARNING', 'Metadata: `'..root..alias..'` '
                         ..'is a duplicate of `'..root..official..'`, '
                        ..'it will be ignored.')
                    map[alias] = nil
                elseif map[alias] then
                    map[official] = map[alias]
                    map[alias] = nil
                end
            end
        end
        return map
    end

    local aliases = {
        global = 'global-metadata',
        metadata = 'child-metadata',
    }
    meta = make_official(aliases, '', meta)

    if meta.imports and type(meta.imports) == 'List' then 
        local aliases = {
            metadata = 'child-metadata'
        }
        for i = 1, #meta.imports do
            local rt = 'imports[' .. i .. ']/'
            meta.imports[i] = make_official(aliases, rt, meta.imports[i])
        end
    end

    if meta.collection and type(meta.collection) ~= 'table' then
        local filepath = stringify(meta.collection)
        log('INFO', 'Assuming `collection` is a defaults file ' 
            .. 'filepath: ' .. filepath .. '.' )
        meta.collection = pandoc.MetaMap({
            defaults = filepath
        })
    end

    if meta.offprints and type(meta.offprints) ~= 'table' then
        local filepath = stringify(meta.offprints)
        log('INFO', 'Assuming `offprints` is a defaults file ' 
            .. 'filepath: ' .. filepath .. '.' )
        meta.offprints = pandoc.MetaMap({
            defaults = filepath
        })
    end

    return meta
end

return normalize_meta
--[[-- # Collection builder - Building collections with Pandoc

@author Julien Dutant <https://github.com/jdutant>
@copyright 2021-2024 Philosophie.ch
@license MIT - see LICENSE file for details.
@release 0.5
]]
PANDOC_VERSION:must_be_at_least '3.1.1' -- for pandoc.json
local system = pandoc.system
local path = pandoc.path
local stringify = pandoc.utils.stringify
local type = pandoc.utils.type

local log = require('log')
local file = require('file')
local prefix_crossref_ids_filter = require('prefix_crossref_ids_filter')
local prefix_ids_filter = require('prefix_ids_filter')
local normalize_meta = require('normalize_meta')

-- # Filter settings

--  environement variables
local env = {
    working_directory = system.get_working_directory(),
}
env.input_folder = path.directory(PANDOC_STATE['input_files'][1])

-- setup map
-- further fields that may be added:
--  - gather: strings list, metadata keys to gather from children
--  - replace: strings list, metadata keys to be replaced by children's ones
--  - pass: strings list, metadata keys to be passed onto children
--  - globalize: strings list, metadata keys to be made global onto children
local setup = {
    do_something = false, -- whether the filter needs to do anything
    isolate = false, -- whether to isolate sources by default
    needs_isolate_filter = false, -- whether the prefix-ids filters are needed
    offprint_mode = false, -- whether we're in offprint mode
}

-- # Helper functions

--- meta_to_yaml: converts MetaMap to yaml, returns empty string if failed.
---@param map pandoc.MetaMap
---@return string result
local function meta_to_yaml (map)
    if type(map) ~= 'Meta' then
        map = pandoc.Meta(map)
    end

    ---@param str string
    ---@return string
    local function extract_yaml (str)
        return str:match("^%-%-%-\n(.*\n)%-%-%-\n") or ''
    end

    local str = pandoc.write(
        pandoc.Pandoc({}, map),
        'markdown',
        {template = pandoc.template.default('markdown')}
    )

    return extract_yaml(str)

end
---save Meta or Metamap as a yaml file
-- uses pandoc to convert Meta or Metamap to yaml.
-- a converter would be faster, but would need to parse Meta elements.
---comment
---@param map pandoc.Meta|pandoc.MetaMap
---@param filepath string
---@return boolean success
local function save_meta_as_yaml(map, filepath)

    yaml = meta_to_yaml(map)

    local success = file.write(yaml, filepath)

    if success then
        return true
    else
        return false
    end

end

-- # Collection functions

--- gather_and_replace: gather or replace selected keys in the main 
--  document based on source files metadata. 
-- Keys to be gather or replaced are listed in `setup.gather` and
-- `setup.replace`.
-- Gather behaviour: if a key preexists we make a list with the old and
-- new values; it both are lists we merge them. Useful for bibliographies,
-- header-includes. 
-- Replace behaviour: if a key preexists we replace it with the source's
-- values; if present in different sources, the last one prevails. Useful
-- in offprint mode (single source) or for keys that don't overlap across
-- sources. 
-- If a key is set to be gathered and replaced, it will be replaced.
local function gather_and_replace(meta)
    for _,item in ipairs(meta.imports) do
        -- we know `item `is a MetaMap, but not if it has a `file` key
        -- if it doesn't we skip it
        if not item.file then
            goto continue
        end

        -- read and parse the file
        local filepath = stringify(item.file)
        local success, contents = file.read(filepath)
        if not success then
            log('ERROR', 'Cannot read file '..filepath..'.')
            return
        end
        local itemdoc = pandoc.read(contents)

        -- for each key to gather, we check if it exists
        -- and we import it in our document's metadata
        -- merging behaviour:
        --  if the preexisting is a list, we append
        --  if the preexisting key has a value, we turn into
        --      a list and we append
        if setup.gather then 
            for _,key in ipairs(setup.gather) do
                if itemdoc.meta[key] then
                    if not meta[key] then
                        meta[key] = itemdoc.meta[key]:clone()
                    else
                        if type(meta[key]) ~= 'List' then
                            meta[key] = pandoc.MetaList(meta[key])
                        end
                        if type(itemdoc.meta[key]) == 'List' then
                            meta[key]:extend(itemdoc.meta[key])
                        else
                            meta[key]:insert(itemdoc.meta[key])
                        end
                    end
                end
            end
        end

        -- for each key to replace, we import it in the document's meta
        if setup.replace then
            for _,key in ipairs(setup.replace) do
                if itemdoc.meta[key] then
                    meta[key] = itemdoc.meta[key]
                end
            end
        end

        :: continue ::
    end
    return meta
end

--- globalize_and_pass: globalize selected metadata fields into 
-- the `global-metadata` map and place selected metadata fields into
-- the `child-metadata` map. 
-- merging behaviour: warn and erase preexisting keys in `global/child
-- -metadata`. 
-- creates `global/child-metadata` keys only if needed
-- @param meta
-- @param setup.globalize global variable
-- @return metadata document
local function globalize_and_pass(meta)
    -- mapping `setup` keys with `meta` keys
    local map = { 
        globalize = 'global-metadata',
        pass = 'child-metadata'
    }
    for setupkey, metakey in pairs(map) do
        -- are there `setup.globalize` or `setup.pass` keys?
        if setup[setupkey] then 
            for _,key in ipairs(setup[setupkey]) do
                -- is there a `key` field in metadata to copy?
                if meta[key] then
                    -- copy in the `metakey` field, warn if merging
                    if not meta[metakey] then
                        meta[metakey] = pandoc.MetaMap({})
                        meta[metakey][key] = meta[key]
                    elseif not meta[metakey][key] then
                        meta[metakey][key] = meta[key]
                    else
                        -- "pass/globalize `key` replaced `key` in `metakey`"
                        log('WARNING', 'Metadata: ' .. setupkey ..
                            ' `' .. key .. '` replaced `' .. key .. 
                            '` in `' .. metakey .. '`.')
                        meta[metakey][key] = meta[key]
                    end
                end
            end
        end
    end
    return meta
end

--- import_sources: import sources into the main document
-- passes metadata to sources using a temporary metadata file,
-- runs pandoc on them in the required mode and places the 
-- result in the main document
local function import_sources(doc, tmpdir)

    -- CONSTANTS
    local acceptable_modes = pandoc.List:new({'native', 'raw', 'direct'})

    -- save_yaml_if_needed: if element isn't a map, assume it's
    -- a filepath to metadata file; otherwise save a temp
    -- yaml file `default_filename`. Either way, returns a filepath.
    local function save_yaml_if_needed(element, default_filename)
        if type(element) ~= 'table' and type(element) ~= 'Meta' then
            return stringify(element)
        else
            local filepath = path.join({tmpdir, default_filename})
            local success = save_meta_as_yaml(element,filepath)
            if not success then
                log('ERROR', 'Could not write '..filepath..'.')
                os.exit(1)
            else
                return filepath
            end
        end
    end

    -- GENERIC import features: metadata, defaults, mode, isolation
    local generic_meta_fpath = ''
    local generic_defaults_fpath = ''
    local generic_mode = 'native'

    -- Do we need to pass generic metadata? 
    -- If yes, prepare a temp file
    if doc.meta['global-metadata'] or doc.meta['child-metadata'] then
        generic_meta_fpath = path.join( { tmpdir , 'generic_meta.yaml' })
        -- `child-metadata` goes to the root, `global-metadata` is
        -- inserted as is
        local metamap = pandoc.MetaMap(doc.meta['child-metadata'] or {})
        metamap['global-metadata'] = doc.meta['global-metadata'] or nil
        save_meta_as_yaml(metamap, generic_meta_fpath)
    end

    -- Do we need to pass generic defaults? 
    -- If yes, are we given a file or a map to save as a temp file?
    -- (yes if `collection` has a `defaults` key that is a map)
    if doc.meta.collection and doc.meta.collection.defaults then
        generic_defaults_fpath = save_yaml_if_needed(
            doc.meta.collection.defaults, 'generic_defaults.yaml')
    end

    -- DEBUG: display a temp yaml files
    -- local file = io.open(generic_meta_fpath, 'r')
    -- print('Generic meta yaml file ', generic_meta_fpath, ':')
    -- print(file:read('a'))
    -- file:close()
    -- local file = io.open(generic_defaults_fpath, 'r')
    -- print('Generic defaults yaml file ', generic_defaults_fpath, ':')
    -- print(file:read('a'))
    -- file:close()

    -- set a generic import mode
    if doc.meta.collection and doc.meta.collection['mode'] then
        str = stringify(doc.meta.collection['mode'])
        if acceptable_modes:find(str) then
            generic_mode = str
        end
    end

    -- will we need our internal filters? 
    -- if yes, save them as tmp files
    -- for the isolate filter, get any user-specified custom prefix pattern
    local isolate_prefix_pattern = "c%d-"
    local prefix_ids_filter_fpath = ''
    local prefix_crossref_ids_filter_fpath = ''
    if setup.needs_isolate_filter then
        if doc.meta.collection['isolate-prefix-pattern'] then
            isolate_prefix_pattern = stringify(doc.meta.collection['isolate-prefix-pattern'])
        end
        prefix_ids_filter_fpath = path.join({tmpdir, 'prefix-ids.lua'})
        prefix_crossref_ids_filter_fpath = path.join({tmpdir, 
            'prefix-crossref-ids.lua'})
        local file = io.open(prefix_ids_filter_fpath, 'w')
        file:write(prefix_ids_filter)
        file:close()
        local file = io.open(prefix_crossref_ids_filter_fpath, 'w')
        file:write(prefix_crossref_ids_filter)
        file:close()
    end

    -- MAIN LOOP to import each item in the list
    -- `i` will be used as unique identifier if needed

    for i = 1, #doc.meta.imports do
        item = doc.meta.imports[i]

        -- we can rely on item being a MetaMap
        -- but if it doesn't have a `file` field nothing to do, 
        -- move on to the next one
        if not item.file then
            goto continue
        end

        -- LOCAL import features: source, metadata, defaults, mode, merge
        local source = stringify(item.file)
        local local_meta_fpath = ''
        local local_defaults_fpath = ''
        local mode = generic_mode
        local merge_defaults = false
        local merge_meta = true
        local isolate = false

        -- do we need local metadata? 
        if item['child-metadata'] then
            local_meta_fpath = save_yaml_if_needed(
                item['child-metadata'], 'local_meta.yaml' )
        end

        -- DEBUG: display local yaml file
        -- if local_meta_fpath ~= '' then 
        --     print('IMPORT #', i, local_meta_fpath)
        --     local f = io.open(local_meta_fpath, 'r')
        --     print(f:read('a'))
        --     f:close()
        -- end

        -- do we need local defaults?
        if item['defaults'] then
            local_defaults_fpath = save_yaml_if_needed(
                item['defaults'], 'local_defaults.yaml' )
        end

        -- do we have a local mode?
        if item.mode then
            local str = stringify(item.mode)
            if acceptable_modes:find(str) then
                mode = str
            end
        end

        -- merge meta and or defaults?
        if item['merge-defaults'] and item['merge-defaults'] == true then
            merge_defaults = true
        end
        if item['merge-metadata'] and item['merge-metadata'] == true then
            merge_meta = true
        end

        -- isolate this specific item?
        if item.isolate and item.isolate == true then
            isolate = true
        elseif item.isolate and item.isolate == false then
            isolate = false
        else
            isolate = setup.isolate
        end

        -- COMMAND LINE ARGUMENTS

        -- source filepath
        local arguments = pandoc.List:new({source})

        -- add source's directory to the resource path, if different
        -- from the working directory.
        -- in case biblios, defaults, are specified relative to it
        --      get current resource path table, insert the source folder
        if path.directory(source) ~= '.' then
            local paths = pandoc.List:new(PANDOC_STATE.resource_path)
            paths:insert(path.directory(source))
            --      build a string with paths separated by ':'
            local path_str = ''
            for i = 1, #paths do
                path_str = path_str .. paths[i]
                if i < #paths then
                    path_str = path_str .. ':'
                end
            end
            if path_str ~= '' then
                arguments:extend({'--resource-path', path_str})
            end
        end

        -- if isolate, add a prefix and apply the pandoc-crossref
        -- filter upfront 
        if isolate then
            arguments:extend({
                '-M', 'prefix-ids-prefix=' .. 
                    string.format(isolate_prefix_pattern, i),
                '-L', prefix_crossref_ids_filter_fpath,
            })  
        end

        -- add any generic defaults and metadata
        -- if no local ones provided or if we're asked to merge
        if generic_meta_fpath ~= '' then
            if local_meta_fpath == '' or merge_meta == true then
                arguments:extend({'--metadata-file', generic_meta_fpath})
            end
        end 
        if generic_defaults_fpath ~= '' then
            if local_defaults_fpath == '' or merge_defaults == true then
                arguments:extend({'--defaults', generic_defaults_fpath})
            end
        end

        -- add any local defaults and metadata
        if local_meta_fpath ~= '' then
            arguments:extend({'--metadata-file', local_meta_fpath})
        end 
        if local_defaults_fpath ~= '' then
            arguments:extend({'--defaults', local_defaults_fpath})
        end

        --      match verbosity
        if PANDOC_STATE.verbosity == 'INFO' then
            arguments:insert('--verbose')
        elseif PANDOC_STATE.verbosity == 'ERROR' then
            arguments:insert('--quiet')
        end

        -- if isolate, apply the prefix-ids filter last
        if isolate then
            arguments:extend({'-L', prefix_ids_filter_fpath})   
        end

        --  function to inform users of the command we're running
        local function inform(src, args)
            local argstring = ''
            for i = 2, #args do
                argstring = argstring .. ' ' .. args[i]
            end
            log('INFO', 'Running pandoc on ' .. src .. ' with ' .. argstring)
        end

        --  run the commands for the required mode
        if mode == 'native' then
    
            -- @TODO need to modify to have FORMAT right and yet 
            -- catch the result in native format
            -- @TODO piping may fail in windows WSL
            arguments:extend({'-t', 'json'})
            inform(source, arguments)
            local result = pandoc.read(pandoc.pipe('pandoc', arguments, ''), 'json')
            doc.blocks:extend(result.blocks)

        elseif mode == 'raw' then

            arguments:extend({'-t', FORMAT})
            inform(source, arguments)

            -- piping on Win (WSL) adds newlines. We save to a temp file instead

            -- local result = pandoc.pipe('pandoc', arguments, '')
            -- doc.blocks:insert(pandoc.RawBlock(FORMAT, result))

            local tmp_outfile = path.join {tmpdir, 'out.'..FORMAT}

            arguments:extend({'-o', tmp_outfile })
            pandoc.pipe('pandoc', arguments, '')
            local file = io.open(tmp_outfile, 'r')
            local result = file:read('a')
            file:close()
            doc.blocks:insert(pandoc.RawBlock(FORMAT, result))

        elseif mode == 'direct' then

            -- @TODO write
        end

        :: continue ::
    end

    return doc

end

-- build: call the import_sources function with a temporary directory
function build(doc)

    if setup.do_something == true then
        system.with_temporary_directory('collection', function(tmpdir)
                doc = import_sources(doc, tmpdir)
            end)
        return doc
    end

end

--- prepare: prepare document metadata for building
-- gather, globalize and pass metadata, offprint mode
function prepare(meta)

    -- check meta.imports
    -- do nothing if it doesn't exist, ensure it's a list otherwise
    if not meta.imports then
        log('INFO', "No `imports` field in ".. PANDOC_STATE['input_files'][1] 
            .. ", nothing to import.")
        return meta
    elseif type(meta.imports) ~= 'List' then
        meta.imports = pandoc.MetaList(meta.imports)
    end
    setup.do_something = true

    -- ensure each item is a MetaMap; if not, assume it's a filename
    -- nb, we change this in the doc itself, in case later filters
    -- rely on this field too. 
    for i = 1, #meta.imports do
        if type(meta.imports[i]) ~= 'table' then
            meta.imports[i] = pandoc.MetaMap({ 
                file = pandoc.MetaString(stringify(meta.imports[i])) 
            })
        end
    end
    -- NOTE bear in mind some `imports` items may still lack a `file` key
    -- this allows users to deactivate a source without removing its data
    -- by changing `file` to `fileoff` for instance

    -- check that each `file` exists. If not, issue an error message
    -- and turn off the `file` key
    for i = 1, #meta.imports do
        if meta.imports[i].file then
            filepath = stringify(meta.imports[i].file)
            if filepath == '' then
                meta.imports[i].file = nil -- clean up deficient values
            else 
                -- try to open
                f = io.open(filepath, 'r')
                if f then
                    f:close()
                else
                    log('ERROR', 'File '..filepath..' not found.')
                    meta.imports[i].fileoff = filepath
                    meta.imports[i].file = nil
                end
            end
        end
    end

    -- offprint mode? if yes we reduce the imports list to that item
    -- warn if we can't make sense of the `offprint-mode` field 
    -- if `offprints` is present we replace `collection` with it
    if meta['offprint-mode'] then
        local index = tonumber(stringify(meta['offprint-mode']))
        if index and meta.imports[index] then
            setup.offprint_mode = true
            meta.imports = pandoc.MetaList({meta.imports[index]})
            if meta.offprints then 
                meta.collection = meta.offprints
            end
            log('INFO', 'Offprint mode, source number ' .. tostring(index))
        else
            meta['offprint-mode'] = nil
            log('WARNING', 'The offprint required (' .. tostring(index) 
                .. ") doesn't exist, ignoring offprint mode.")
        end
    end

    --- if not offprint mode, mark the first import as `collection-first-import`
    --- see below

    -- build lists of metadata keys to gather, globalize and pass
    if meta.collection then
        for _,key in ipairs({'gather','replace', 'globalize', 'pass'}) do
            if meta.collection[key] then
                if type(meta.collection[key]) ~= 'List' then
                    meta.collection[key] = pandoc.MetaList(meta.collection[key])
                end
                setup[key] = pandoc.List:new()
                for _,entry in ipairs(meta.collection[key]) do
                    setup[key]:insert(stringify(entry))
                end
            end
        end
    end

    -- gather and replace main metadata using source files values
    if setup.gather or setup.replace then
        meta = gather_and_replace(meta)
    end

    -- globalize and pass the required metadata keys
    if setup.globalize or setup.pass then
        meta = globalize_and_pass(meta)
    end

    -- in non-offprint mode, mark the first import as 'collection-first-import' 
    -- unless this is already set to false
    if not meta['offprint-mode'] and meta.imports[1] then
        meta.imports[1]['child-metadata'] = meta.imports[1]['child-metadata']
            or pandoc.MetaMap {}
        if meta.imports[1]['child-metadata']['collection-first-import'] ~= false then
            meta.imports[1]['child-metadata']['collection-first-import'] = true
        end
    end

    -- ISOLATE
    -- do we isolate sources by default?
    if meta.collection and meta.collection.isolate == true then
        setup.isolate = true
        setup.needs_isolate_filter = true
    end
    -- is the filter otherwise needed to isolate some specific source
    if not setup.needs_isolate_filter then
        for _,item in ipairs(meta.imports) do
            if item.isolate and item.isolate == true then
                setup.needs_isolate_filter = true
                break
            end
        end
    end

    return meta

end

--- Main filter
return {
    {
        Meta = function(meta)
            return normalize_meta(meta)
        end,
        Pandoc = function(doc)
            doc.meta = prepare(doc.meta)
            return build(doc)
        end
    }
}

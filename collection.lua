--[[-- # Collection builder - a Lua filter to build
volumes and journal issues in Pandoc's markdown

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2021 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.3
]]

-- # Filter settings

-- # Global variables

local utils = pandoc.utils
local system = pandoc.system
local path = require('pandoc.path')

--	environement variables
local env = {
	working_directory = system.get_working_directory(),
}
env.input_folder = path.directory(PANDOC_STATE['input_files'][1])

-- setup map
-- further fields that may be added:
--  - gather: strings list, metadata keys to gather from children
-- 	- pass: strings list, metadata keys to be passed onto children
--	- globalize: strings list, metadata keys to be made global onto children
local setup = {
	do_something = false, -- whether the filter needs to do anything
	isolate = false, -- whether to isolate sources by default
	needs_isolate_filter = false, -- whether the isolate filter is needed
	offprint_mode = false, -- whether we're in offprint mode
}

-- # Helper functions

--- message: send message to std_error
-- @param type string INFO, WARNING, ERROR
-- @param text string message text
function message(type, text)
    local level = {INFO = 0, WARNING = 1, ERROR = 2}
    if level[type] == nil then type = 'ERROR' end
    if level[PANDOC_STATE.verbosity] <= level[type] then
        io.stderr:write('[' .. type .. '] Collection lua filter: ' 
            .. text .. '\n')
    end
end

--- to_json: converts a entire Pandoc document to json
-- run_json_filter passes a Pandoc object as json to stdin
-- we use regex to put it in the RawBlock of a wrapping json
-- representation of a Pandoc object, so that we can
-- recover the json string.
-- @param doc pandoc Pandoc object
-- @string if success, nil if failed
-- @TODO in Win, use Python or Perl if present, powershell is slow
function to_json(doc)

	-- check that doc is a Pandoc object
	if not (doc.meta and doc.blocks) then
		return nil
	end
	-- prepare command to wrap json stdin in a json representation
	-- of a Pandoc document. Use sed on *nix and powershell on windows
	local command = ''
	local arguments = pandoc.List:new()
	--	strings to build an empty document with a RawBlock element
	local api_ver_str = tostring(PANDOC_API_VERSION):gsub('%.',',')
	local before = '{"pandoc-api-version":[' .. api_ver_str .. '],'
		.. [["meta":{},"blocks":[{"t":"RawBlock","c":["json","]]
	local after =	[["]}]}]]
	local result = nil
	if pandoc.system.os == 'mingw32' then
		-- we need to set input and output in utf8
		-- before run_json_filter is called
		-- [Console]::OutputEncoding for stdin
		-- $OutputEncoding for stdout
		-- see https://stackoverflow.com/questions/49476326/displaying-unicode-in-powershell
		-- @TODO find a way to restore later! we can't use variables
		-- as they are dumped at the end of this call
		os.execute([[PowerShell -NoProfile -Command ]]
			.. ' [Console]::OutputEncoding=[Text.Encoding]::utf8;'
			.. ' $OutputEncoding=[Text.Encoding]::utf8;'
			)
		command = 'powershell'
		arguments:extend({'-NoProfile', '-Command'})
		-- write the powershell script
		-- (for some reason it isn't necessary to wrap it in double quotes)
		local pwsh_script = ''
		-- manipulate stdin
		pwsh_script = pwsh_script .. '$input'
		-- escape backslashes and double quotes
		pwsh_script = pwsh_script .. [[ -replace '\\','\\']]
			.. [[ -replace '\"','\"']]
		-- wrap the result in an empty document with a RawBlock element
		pwsh_script = pwsh_script .. " -replace '^','" .. before .. "'"
				.. " -replace '$','" .. after .. "'"
		arguments:insert(pwsh_script)

		result = pandoc.utils.run_json_filter(doc, command, arguments)
		-- restore console settings here

	else
		command = 'sed'
		local sed_script = ''
		-- escape backlashes and double quotes
		sed_script = sed_script .. [[s/\\/\\\\/g; ]] .. [[s/\"/\\"/g; ]]
		-- wrap the result in an empty document with a RawBlock element
		sed_script = sed_script .. [[s/^/]] .. before .. [[/; ]] 
			.. [[s/$/]] .. after .. [[/; ]]
		arguments:insert(sed_script)

		result = pandoc.utils.run_json_filter(doc, command, arguments)

	end

	-- catch the result in the `text` field of the first block
	-- return nil if faileds
	return result.blocks[1].c[2] or nil

end

--- save_meta_as_yaml: save Meta or Metamap as a yaml file
-- uses pandoc to convert Meta or Metamap to yaml.
-- a converter would be faster, but would need to parse Meta elements.
function save_meta_as_yaml(map,filepath)
	-- build an Pandoc document with map as meta
	local doc = pandoc.Pandoc({}, pandoc.Meta(map))
	-- convert the doc to json, so we can send it to pandoc.pipe
	local yaml = ''
	local json = to_json(doc)
	-- pipe it to pandoc to convert to markdown
	if json then 
		yaml = pandoc.pipe('pandoc', {'-f', 'json', '-s', '-t', 'markdown'}, json)
		-- catch the block between first two `---` lines
		yaml = string.match(yaml, "^%-%-%-\n(.*\n)%-%-%-\n") or ''
	end

	-- save file, even if empty
	local file = io.open(filepath, 'w')
	file:write(yaml)
	file:close()

end

-- # Isolate filter
--		This filter will be ran on imported document if we need to isolate them
--		Needs to be a saved as a temporary file to do so
isolate_filter = [[
---- # Prefix-ids - Prefixings all ids in a Pandoc document

-- @author Julien Dutant <julien.dutant@kcl.ac.uk>
-- @copyright 2021 Julien Dutant
-- @license MIT - see LICENSE file for details.
-- @release 0.1

-- # Global variables
local prefix = ''
local old_identifiers = pandoc.List:new()
local pandoc_crossref = true
local crossref_prefixes = pandoc.List:new({'fig','sec','eq','tbl','lst'})

--- get_options: get filter options for document's metadata
-- @param meta pandoc Meta element
function get_options(meta)

    -- syntactic sugar: options aliases
    -- merging behaviour: aliases prevail
    local aliases = {'prefix', 'pandoc-crossref'}
    for _,alias in ipairs(aliases) do
        if meta['prefix-ids-' .. alias] ~= nil then
            -- create a 'prefix-ids' key if needed
            if not meta['prefix-ids'] then
                meta['prefix-ids'] = pandoc.MetaMap({})
            end
            meta['prefix-ids'][alias] = meta['prefix-ids-' .. alias]
            meta['prefix-ids-' .. alias] = nil
        end
    end

    -- save options in global variables
    if meta['prefix-ids'] then

        if meta['prefix-ids']['prefix'] then
            prefix = pandoc.utils.stringify(meta['prefix-ids']['prefix'])
        end
        if meta['prefix-ids']['pandoc-crossref'] ~= nil 
          and meta['prefix-ids']['pandoc-crossref'] == false then
            pandoc_crossref = false
        end
        
    end
    return meta
end

--- process_doc: process the pandoc document
-- generates a prefix is needed, walk through the document
-- and adds a prefix to all elements with identifier.
-- @param pandoc Pandoc element
-- @TODO handle meta fields that may contain identifiers? abstract
-- and thanks?
function process_doc(doc)

    -- generate prefix if needed
    if prefix == '' then
        prefix = pandoc.utils.sha1(pandoc.utils.stringify(doc.blocks))
    end

    -- add_prefix function
    -- do not add prefixes to empty identifiers
    -- store the old identifiers for fixing the links
    add_prefix = function (el) 
        if el.identifier and el.identifier ~= '' then
            old_identifiers:insert(el.identifier)
            local new_identifier = ''
            -- if pandoc-crossref type, we add the prefix after "fig:"
            if pandoc_crossref then 
                local type = el.identifier:match('^(%a+):')
                if crossref_prefixes:find(type) then
                    new_identifier = type .. ':' .. prefix 
                        .. el.identifier:match('^%a+:(.*)')
                else
                    new_identifier = prefix .. el.identifier
                end
            else
                new_identifier = prefix .. el.identifier
            end
            el.identifier = new_identifier
            return el
        end
    end
    -- add_prefix_string function
    -- same as add_prefix but for pandoc-crossref "{eq:label}" strings
    add_prefix_string = function(el)
        local eq_identifier = el.text:match('{#eq:(.*)}')
        if eq_identifier then
            old_identifiers:insert('eq:' .. eq_identifier)
            return pandoc.Str('{#eq:' .. prefix .. eq_identifier .. '}')
        end
    end

    -- apply the function to all elements with identifier
    local div = pandoc.walk_block(pandoc.Div(doc.blocks), {
        Span = add_prefix,
        Link = add_prefix,
        Image = add_prefix,
        Code = add_prefix,
        Div = add_prefix,
        Header = add_prefix,
        Table = add_prefix,
        CodeBlock = add_prefix,
        Str = pandoc_crossref and add_prefix_string
    })
    doc.blocks = div.content

    -- function to add prefixes to links
    local add_prefix_to_link = function (link)
        if link.target:sub(1,1) == '#' 
          and old_identifiers:find(link.target:sub(2,-1)) then
            local target = link.target:sub(2,-1)
            -- handle pandoc-crossref types targets if needed
            if pandoc_crossref then
                local type = target:match('^(%a+):')
                if crossref_prefixes:find(type) then
                    target = '#' .. type .. ':' .. prefix 
                        .. target:match('^%a+:(.*)')
                else
                    target = '#' .. prefix .. target
                end
            else
                target = '#' .. prefix .. target
            end
            link.target = target
            return link 
        end
    end
    -- function to add prefixes to pandoc-crossref citations
    -- looking for keys starting with `fig:`, `sec:`, `eq:`, ... 
    local add_prefix_to_crossref_cites = function (cite)
        for i = 1, #cite.citations do
            local type = cite.citations[i].id:match('^(%a+):')
            if crossref_prefixes:find(type) then
                local target = cite.citations[i].id:match('^%a+:(.*)')
                if old_identifiers:find(type .. ':' .. target) then
                    target = prefix .. target
                    cite.citations[i].id = type .. ':' .. target
                end
            end
        end
        return cite
    end

    div = pandoc.walk_block(pandoc.Div(doc.blocks), {
        Link = add_prefix_to_link,
        Cite = pandoc_crossref and add_prefix_to_crossref_cites
    })
    doc.blocks = div.content

    -- return the result
    return doc

end

-- # Main filter
return {
    {
        Meta = get_options,
        Pandoc = process_doc
    }
}

]]

-- # Collection functions

--- gather_metadata: gather selected metadata from source files 
-- into the document's metadata. The keys to be gathered
-- are listed in setup.gather. Merging behaviour: if a key
-- preexist we make a list with the old and new values; if
-- both are lists we merge them. 
function gather_metadata(meta)
	for _,item in ipairs(meta.imports) do
		-- we know `item `is a MetaMap, but not if it has a `file` key
		-- if it doesn't we skip it
		if not item.file then
			goto continue
		end

		-- read and parse the file
		local filepath = utils.stringify(item.file)
		local file = io.open(filepath, 'r')
		local itemdoc = pandoc.read(file:read('a'))
		file:close()

		-- for each key to gather, we check if it exists
		-- and we import it in our document's metadata
		-- merging behaviour:
		-- 	if the preexisting is a list, we append
		--  if the preexisting key has a value, we turn into
		--		a list and we append
		for _,key in ipairs(setup.gather) do
			if itemdoc.meta[key] then
				if not meta[key] then
					meta[key] = itemdoc.meta[key]:clone()
				else
					if meta[key].t ~= 'MetaList' then
						meta[key] = pandoc.MetaList(meta[key])
					end
					if itemdoc.meta[key].t == 'MetaList' then
						meta[key]:extend(itemdoc.meta[key])
					else
						meta[key]:insert(itemdoc.meta[key])
					end
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
function globalize_and_pass(meta)
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
						message('WARNING', 'Metadata: ' .. setupkey ..
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
function import_sources(doc, tmpdir)

	-- CONSTANTS
	local acceptable_modes = pandoc.List:new({'native', 'raw', 'direct'})

	-- save_yaml_if_needed: if element is a map, save it as 
	-- a temp yaml file `default_filename', otherwise assume 
	-- it's a filepath. Either way, return a filepath.
	function save_yaml_if_needed(element, default_filename)
		if element.t ~= 'MetaMap' then
			return utils.stringify(element)
		else
			local filepath = path.join({tmpdir, default_filename})
			save_meta_as_yaml(element,filepath)
			return filepath
		end
	end

	-- GENERIC import features: metadata, defaults, mode, isolation
	local generic_meta_fpath = ''
	local generic_defaults_fpath = ''
	local generic_mode = 'native'

	-- Do we need to pass generic metadata? If yes, get/make a file
	-- If yes, prepare a temp file
	if doc.meta['global-metadata'] or doc.meta['child-metadata'] then
		generic_meta_fpath = path.join( { tmpdir , 'generic_meta.yaml' })
		-- `child-metadata` goes to the root, `global-metadata` is
		-- inserted as is
		local metamap = pandoc.MetaMap(doc.meta['child-metadata'])
		metamap['global-metadata'] = doc.meta['global-metadata']
		save_meta_as_yaml(metamap, generic_meta_fpath)
	end

	-- Do we need to pass generic defaults? 
	-- If yes, are we given a file or a map to save as a temp file?
	-- (yes if `collection` has a `defaults` key that is a map)
	if doc.meta.collection and doc.meta.collection.defaults then
		generic_defaults_fpath = save_yaml_if_needed(
			doc.meta.collection.defaults, 'generic_defaults.yaml')
	end

	-- DEBUG: display a temp yaml file
	-- local file = io.open(generic_defaults_fpath, 'r')
	-- print('yaml file: ')
	-- print(file:read('a'))
	-- file:close()

  	-- set a default import mode
	if doc.meta.collection and doc.meta.collection['mode'] then
		str = utils.stringify(doc.meta.collection['mode'])
		if acceptable_modes:find(str) then
			generic_mode = str
		end
	end

	-- if the `isolate.lua` filter is needed, save it as tmp file
	-- and get the user-specified custom isolate prefix if any
	local isolate_prefix_pattern = "c%d-"
	local isolate_filter_fpath = ''
	if setup.needs_isolate_filter then
		if doc.meta.collection['isolate-prefix-pattern'] then
			isolate_prefix_pattern = utils.stringify(doc.meta.collection['isolate-prefix-pattern'])
		end
		isolate_filter_fpath = path.join( { tmpdir , 'isolate.lua' })
		local file = io.open(isolate_filter_fpath, 'w')
		file:write(isolate_filter)
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
		local source = utils.stringify(item.file)
		local local_meta_fpath = ''
		local local_defaults_fpath = ''
		local mode = generic_mode
		local merge_defaults = false
		local merge_meta = false
		local isolate = false

		-- do we need local metadata? 
		if item['child-metadata'] then
			local_meta_fpath = save_yaml_if_needed(
				item['child-metadata'], 'local_meta.yaml' )
		end

		-- do we need local defaults?
		if item['defaults'] then
			local_defaults_fpath = save_yaml_if_needed(
				item['defaults'], 'local_defaults.yaml' )
		end

		-- do we have a local mode?
		if item.mode then
			local str = utils.stringify(item.mode)
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
		--		get current resource path table, insert the source folder
		if path.directory(source) ~= '.' then
			local paths = pandoc.List:new(PANDOC_STATE.resource_path)
			paths:insert(path.directory(source))
			--		build a string with paths separated by ':'
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

		-- run the isolate filter with a prefix, if needed
		-- placed here to apply before pandoc-crossref
		if isolate then
			arguments:extend({'-L', isolate_filter_fpath, 
			'-M', 'prefix-ids-prefix='.. string.format(isolate_prefix_pattern, i) })	
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

		--		match verbosity
		if PANDOC_STATE.verbosity == 'INFO' then
			arguments:insert('--verbose')
		elseif PANDOC_STATE.verbosity == 'ERROR' then
			arguments:insert('--quiet')
		end

		-- 	function to inform users of the command we're running
		local function inform (src, args)
			local argstring = ''
			for i = 2, #args do
				argstring = argstring .. ' ' .. args[i]
			end
			message('INFO', 'Running pandoc on ' .. src .. ' with ' .. argstring)
		end

		--	run the commands for the required mode
		if mode == 'native' then
	
			-- @TODO need to modify to have FORMAT right and yet 
			-- catch the result in native format
			arguments:extend({'-t', 'json'})
			inform(source, arguments)
			local result = pandoc.read(pandoc.pipe('pandoc', arguments, ''), 'json')
			doc.blocks:extend(result.blocks)

		elseif mode == 'raw' then

			arguments:extend({'-t', FORMAT})
			inform(source, arguments)
			local result = pandoc.pipe('pandoc', arguments, '')
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
		message('INFO', "No `imports` field in ".. PANDOC_STATE['input_files'][1] 
			.. ", nothing to import.")
		return meta
	elseif meta.imports.t ~= 'MetaList' then
		meta.imports = pandoc.MetaList(meta.imports)
	end
	setup.do_something = true

	-- ensure each item is a MetaMap; if not, assume it's a filename
	-- nb, with fix this in the doc itself, in case later filters
	-- need this info. 
	for i = 1, #meta.imports do
		if meta.imports[i].t ~= 'MetaMap' then
			meta.imports[i] = pandoc.MetaMap({ 
				file = pandoc.MetaString(utils.stringify(meta.imports[i])) 
			})
		end
	end
	-- bear in mind some `imports` items may still lack a `file` key
	-- this allows users to deactive a source without removing its data
	-- by changing `file` to `fileoff` for instance

	-- offprint mode? if yes we reduce the imports list to that item
	-- warn if we can't make sense of the `offprint-mode` field 
	-- if `offprints` is present we replace `collection` with it
	if meta['offprint-mode'] then
		local index = tonumber(utils.stringify(meta['offprint-mode']))
		if index and meta.imports[index] then
			setup.offprint_mode = true
			meta.imports = pandoc.MetaList(meta.imports[index])
			if meta.offprints then 
				meta.collection = meta.offprints
			end
			message('INFO', 'Offprint mode, source number ' .. index)
		else
			message('WARNING', 'The offprint required (' .. index 
				.. ") doesn't exist, ignoring offprint mode.")
		end
	end

	-- build lists of metadata keys to gather, globalize and pass
	if meta.collection then
		for _,key in ipairs({'gather', 'globalize', 'pass'}) do
			if meta.collection[key] then
				if meta.collection[key].t ~= 'MetaList' then
					meta.collection[key] = pandoc.MetaList(meta.collection[key])
				end
				setup[key] = pandoc.List:new()
				for _,entry in ipairs(meta.collection[key]) do
					setup[key]:insert(utils.stringify(entry))
				end
			end
		end
	end

	-- gather metadata from source files into the main metadata
	if setup.gather then
		meta = gather_metadata(meta)
	end

	-- globalize and pass the required metadata keys
	if setup.globalize or setup.pass then
		meta = globalize_and_pass(meta)
	end

	-- ISOLATE
	-- do we isolate sources by defaults?
	if not setup.offprint_mode and meta.collection 
	  and meta.collection.isolate == true then
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

--- syntactic_sugar: normalize alias keys in meta
-- in case of duplicates we warn the user and
-- use the ones with more explicit names.
-- if `collection` or `offprints` are strings
-- we assume they're defaults filepaths.
function syntactic_sugar(meta)

	-- function that converts aliases to official fields in a map
	-- following an alias table. 
	-- The map could be the doc's Meta or a MetaMap within it. 
	-- Use `root` to let the user know what the root key was in the 
	-- later case in error messages, e.g. "imports[1]/". 
	-- Merging behaviour: if the official already exists we warn the
	-- user and simply ignore the alias key.
	-- Warning: aliases must be acceptable Lua map keys, so they can't
	-- 	contain e.g. dashes. Official names aren't restricted.
	-- @alias_table table an alias map aliasname = officialname. 
	-- @root string names the root for error messages, e.g. "imports[1]/"
	-- @map Meta or MetaMap to be cleaned up
	function make_official(alias_table, root, map)
		for alias,official in pairs(alias_table) do
			if map[alias] then 
				if not map[official] then
					map[official] = map[alias]
					map[alias] = nil
				else 
					message('WARNING', 'Metadata: `'..root..alias..'` '
						 ..'is a duplicate of `'..root..official..'`, '
						..'it will be ignored.')
				end
			end
		end
		return map
	end

	local aliases = {
		global = 'global-metadata',
		metadata = 'child-metadata'
	}
	meta = make_official(aliases, '', meta)

	if meta.imports then 
		local aliases = {
			metadata = 'child-metadata'
		}
		for i = 1, #meta.imports do
			local rt = 'imports[' .. i .. ']/'
			meta.imports[i] = make_official(aliases, rt, meta.imports[i])
		end
	end

	if meta.collection.t ~= 'MetaMap' then
		local filepath = utils.stringify(meta.collection)
		message('INFO', 'Assuming `collection` is a defaults file ' 
			.. 'filepath: ' .. filepath .. '.' )
		meta.collection = pandoc.MetaMap({
			defaults = filepath
		})
	end

	if meta.offprints and meta.offprints.t ~= 'MetaMap' then
		local filepath = utils.stringify(meta.offprints)
		message('INFO', 'Assuming `offprints` is a defaults file ' 
			.. 'filepath: ' .. filepath .. '.' )
		meta.offprints = pandoc.MetaMap({
			defaults = filepath
		})
	end

	return meta
end

--- Main filter
-- syntactic sugar: normalize alias keys in meta
return {
	{
		Meta = function(meta)
			return syntactic_sugar(meta)
		end,
		Pandoc = function(doc)
			doc.meta = prepare(doc.meta)
			return build(doc)
		end
	}
}
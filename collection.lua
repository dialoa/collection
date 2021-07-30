--[[-- # Collection builder - a Lua filter to build
volumes and journal issues in Pandoc's markdown

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2021 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.2
]]

-- # Filter settings

-- # Global variables

local utils = pandoc.utils
local system = pandoc.system
local path = require('pandoc.path')

local env = {
	working_directory = system.get_working_directory(),
}
env.input_folder = path.directory(PANDOC_STATE['input_files'][1])

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
-- @param doc pandoc Pandoc object
function to_json(doc)

	-- build the perl script
	local script = ''
	-- escape backlashes and double quotes
  script = script .. [[ s/\\/\\\\/g; ]] .. [[ s/\"/\\"/g; ]]
	-- wrap the result in an empty element with a RawBlock element
	local before = '{"pandoc-api-version":[1,22],"meta":{},"blocks":'
									.. '[{"t":"RawBlock","c":["json","'
	local after =	'"]}]}'
	script = script .. [[ s/^/ ]] .. before .. [[ /; ]] 
		.. [[ s/$/ ]] .. after  .. [[ / ]]

	-- run the filter, catch the result in the `text` field of the first block
	local result = pandoc.utils.run_json_filter(doc, 'perl', {'-pe', script})

	-- return the string or nil
	return result.blocks[1].c[2] or nil

end

--- save_meta_as_defaults: converts a Meta or MetaMap to a defaults
-- file with a `metadata` field. The defaults file can then
-- be used to import the metadata map into other files.
-- @param filepath string the file path
-- @param map a Meta or MetaMap pandoc AST object
function save_meta_as_defaults(filepath, map)
	-- build empty doc with meta only
	-- with the map in `metadata` field
	local doc = pandoc.Pandoc({}, pandoc.Meta{ metadata = map})

	-- convert to json then yaml
	local yaml = ''
	local json = to_json(doc)
	if json then
		-- convert to markdown with yaml block
		yaml = pandoc.pipe('pandoc', {'-f', 'json', '-s', '-t', 'markdown'}, json)
		-- extract yaml
		yaml = string.match(yaml, "^%-%-%-\n(.*\n)%-%-%-\n+$") or ''
	end

	-- save file
	local file = io.open(filepath, 'w')
	file:write(yaml)
	file:close()

end

-- # Isolate filter
--		This filter will be ran on imported document if we need to isolate them
--		Needs to be a saved as a temporary file to do so
isolate_filter = [[
-- # Global variables
local prefix = ''
local old_identifiers = pandoc.List:new()

--- get_options: get filter options for document's metadata
-- @param meta pandoc Meta element
function get_options(meta)

    if meta['isolate-prefix'] then
        prefix = pandoc.utils.stringify(meta['isolate-prefix'])
    end

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
            local new_identifier = prefix .. el.identifier
            el.identifier = new_identifier
            return el
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
    })
    doc.blocks = div.content

    local add_prefix_to_link = function (link)
        if link.target:sub(1,1) == '#' 
          and old_identifiers:find(link.target:sub(2,-1)) then
            new_target = '#' .. prefix .. link.target:sub(2,-1)
            link.target = new_target
            return link 
        end
    end

    div = pandoc.walk_block(pandoc.Div(doc.blocks), {
        Link = add_prefix_to_link
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

function import_chapters(doc, tmpdir)

	-- if a yaml file is needed, build it
	local tempyaml = false
	local tempyaml_filepath = ''
	if doc.meta.global and doc.meta.global.t == 'MetaMap' then 
		tempyaml = true
		tempyaml_filepath = path.join( { tmpdir , 'metadata.yaml' })
		local map = { global = doc.meta.global }
		save_meta_as_defaults(tempyaml_filepath, map)
	end
	 
	-- DEBUG: display the temp yaml file
	-- local file = io.open(tempyaml_filepath, 'r')
	-- print(file:read('a'))
	-- file:close()

	-- if the `isolate.lua` filter is needed, save it as tmp file
	-- and get any custom isolate filter specified
	local needs_isolate_filter = false
	if doc.meta.collection and doc.meta.collection['needs-isolate-filter'] then
		needs_isolate_filter = true
		isolate_prefix_pattern = "c%d-"
		if doc.meta.collection['isolate-prefix-pattern'] then
			isolate_prefix_pattern = utils.stringify(doc.meta.collection['isolate-prefix-pattern'])
		end
		isolate_filter_filepath = path.join( { tmpdir , 'isolate.lua' })
		local file = io.open(isolate_filter_filepath, 'w')
		file:write(isolate_filter)
		file:close()
	end

  	-- set a default import mode
	local default_mode = 'native'
	if doc.meta.collection and doc.meta.collection['mode'] then
		str = utils.stringify(doc.meta.collection['mode'])
		if str == 'native' or str == 'raw' then
			default_mode = str
		end
	end

	-- is there a default defaults file?
	local default_defaults = nil
	if doc.meta.collection and doc.meta.collection['defaults'] then
		default_defaults = utils.stringify(doc.meta.collection['defaults'])
	end

	-- go through the list, import each item
	--		i will be used as unique identifier if needed
	for i = 1, #doc.meta.imports do
		item = doc.meta.imports[i]

		-- set the filename
		-- if `item` is a MetaMap without `file` field we can't make sense of it
		-- so move on to next item
		if item.t == 'MetaMap' and not item.file then
			goto continue
		end
		-- if the item isn't a MetaMap, assume it's a filename
		-- nb, instead of merely storing the filename in source
		-- we fix the AST document's metadata. (Given Lua passes
		-- tables by references, modifying `item` modifies `doc`.)
		-- This is safer for future uses and filters run after this one.
		if item.t ~= "MetaMap" then
			item = pandoc.MetaMap({ file = pandoc.MetaString(utils.stringify(item)) })
		end

		-- set the mode and defaults
		-- use the default import mode unless overridden for this item
		local mode = default_mode
		if item.mode then
			local str = utils.stringify(item.mode)
			if str == 'native' or str == 'raw' then
				mode = str
			end
		end
		-- use the default defaults file unless overriden
		-- recall that default_defaults might be nil
		local defaults = default_defaults
		if item.defaults then
			defaults = utils.stringify(item.defaults)
		end

		-- construct the source and default filepaths
		-- note: they are located relative to the master (input) file
		local source = utils.stringify(item.file)
		if path.is_relative(source) then
			source = path.join({ env.input_folder, source} )
		end
		if defaults and path.is_relative(defaults) then
			defaults = path.join({ env.input_folder, defaults })
		end

		-- import to blocks in the required mode

		-- 	build the list of command line arguments
		--		source file
		local arguments = pandoc.List:new({source})
		--		add source directory to resource path
		--		in case biblos, images, are specified relative to it
		arguments:extend({'--resource-path', path.directory(source)})
		--		add defaults and tempyaml if provided
		if defaults then 
			arguments:extend({'-d', defaults})
		end
		if tempyaml then 
			arguments:extend({'-d', tempyaml_filepath})
		end
		--		run the isolate filter with a prefix
		if (doc.meta.collection.isolate and item.isolate ~= false)
			or item.isolate then
			arguments:extend({'-L', isolate_filter_filepath, 
			'-M', 'isolate-prefix='.. string.format(isolate_prefix_pattern, i) })	
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
	
			arguments:extend({'-t', 'json'})
			inform(source, arguments)
			local result = pandoc.read(pandoc.pipe('pandoc', arguments, ''), 'json')
			doc.blocks:extend(result.blocks)

		else -- mode = 'raw'

			arguments:extend({'-t', FORMAT})
			inform(source, arguments)
			local result = pandoc.pipe('pandoc', arguments, '')
			doc.blocks:insert(pandoc.RawBlock(FORMAT, result))

		end

		:: continue ::
	end

	return doc

end

function build(doc)

	-- check doc.meta.imports
	-- do nothing if it doesn't exist, ensure it's a list otherwise
	if not doc.meta.imports then
		message('INFO', "No `imports` field in ".. PANDOC_STATE['input_files'][1] 
			.. ", nothing to import.")
		return nil
	end
	if doc.meta.imports ~= 'MetaList' then
		doc.meta.imports = pandoc.MetaList(doc.meta.imports)
	end

	-- offprint mode? if yes we reduce the imports list to that file
	-- if we can't make sense of the `offprint` field we erase it
	-- and warn the user
	if doc.meta.offprint then
		message('INFO', 'Trying offprint mode')
		local index = tonumber(utils.stringify(doc.meta.offprint))
		if index and doc.meta.imports[index] then
			doc.meta.imports = pandoc.MetaList(doc.meta.imports[index])
		else
			doc.meta.offprint = nil
			message('WARNING', 'The offprint required (' .. index 
				.. ") doesn't exist, cancelling offprint mode.")
		end
	end

	-- do we need a temporary directory?
	--   either to pass metadata yaml, or to have the `isolate.lua` filter 
	local needs_tmpdir = false
	if doc.meta.global and doc.meta.global.t == 'MetaMap' then
		needs_tmpdir = true
	elseif doc.meta.collection and doc.meta.collection.isolate then
		needs_tmpdir = true
		doc.meta.collection['needs-isolate-filter'] = true -- reused later
	else
		for _,item in ipairs(doc.meta.imports) do
			if item.isolate then
				needs_tmpdir = true
				doc.meta.collection['needs-isolate-filter'] = true
				break
			end
		end
	end

	-- create a tmp directory if needed and import chapters
	if needs_tmpdir then
		system.with_temporary_directory('collection', function(tmpdir)
				import_chapters(doc, tmpdir)
			end)
	else
		import_chapters(doc)
	end

	return doc

end

--- Main filter
return {
	{
		Pandoc = function(doc)
			return build(doc)
		end
	}
}
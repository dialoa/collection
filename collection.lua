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

-- # Collection functions

function import_chapters(doc, tempyaml_dir)

	-- do we have a tempyaml directory? if yes, build the temp yaml file
	local tempyaml = false
	local tempyaml_filepath = ''
	if tempyaml_dir then 
		tempyaml = true
		tempyaml_filepath = tempyaml_dir .. path.separator .. 'metadata.yaml'
		local map = { global = doc.meta.global }
		save_meta_as_defaults(tempyaml_filepath, map)
	end

	-- DEBUG: display the temp yaml file
	-- local file = io.open(tempyaml_filepath, 'r')
	-- print(file:read('a'))
	-- file:close()

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
	for _,item in ipairs(doc.meta.imports) do

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
		local arguments = pandoc.List:new({source})
		if defaults then 
			arguments:extend({'-d', defaults})
		end
		if tempyaml then 
			arguments:extend({'-d', tempyaml_filepath})
		end
		if PANDOC_STATE.verbosity == 'INFO' then
			arguments:insert('--verbose')
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

	if not doc.meta.imports then
		message('INFO', "No `imports` field in ".. PANDOC_STATE['input_files'][1] 
			.. ", nothing to import.")
		return nil
	end

	-- ensure doc.meta.imports is a list
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

	-- if there is global metadata to be passed, 
	-- create a yaml for it in a temp directory
	if doc.meta.global and doc.meta.global.t == 'MetaMap' then
		system.with_temporary_directory('metadatayaml', function(tmpdir)
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
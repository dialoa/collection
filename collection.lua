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

	-- do we have a tempyaml directory? if yes, build it
	local tempyaml = false
	local tempyaml_filepath = ''
	if tempyaml_dir then 
		tempyaml = true
		tempyaml_filepath = tempyaml_dir .. path.separator .. 'metadata.yaml'
		local map = { global = doc.meta.global }
		save_meta_as_defaults(tempyaml_filepath, map)
	end

  -- set a the default import mode
	local default_mode = 'native'
	if doc.meta.collection and doc.meta.collection['mode'] then
		str = utils.stringify(doc.meta.collection['mode'])
		if str == 'native' or str == 'raw' then
			mode = str
		end
	end

	-- is there a default defaults file?
	local default_defaults = nil
	if doc.meta.collection and doc.meta.collection['defaults'] then
		default_defaults = utils.stringify(doc.meta.import['defaults'])

	end

	-- DEBUG: display the temp yaml file
	-- local file = io.open(tempyaml_filepath, 'r')
	-- print(file:read('a'))
	-- file:close()

	-- go through the list, import each item
	for _,item in ipairs(doc.meta.imports) do

		-- if item is a MetaMap but without `file` field, give up
		-- and move on to the next
		if item.t == 'MetaMap' and not item.file then
			goto continue
		end

		-- if the item isn't a MetaMap, assume it's a filename
		-- note we're placing this in the AST in case other filters
		-- applied after this one use it
		if item.t ~= "MetaMap" then
			item = pandoc.MetaMap({ file = pandoc.MetaString(utils.stringify(item)) })
		end

		-- construct prefix needed for some filenames
		-- source and defaults files are located relative
		-- the master file. In case pandoc isn't run from the 
		-- directory of the master file, we need to add that
		-- prefix to defaults and source filenames
		local prefix = ''
		if env.input_folder ~= '' then
			prefix = env.input_folder .. path.separator
		end

		-- get the source filepath
		local source = prefix .. utils.stringify(item.file)

		-- use the default import mode unless overriden
		local mode = default_mode
		if item.mode then
			local str = utils.stringify(item.mode)
			if str == 'native' or str == 'raw' then
				mode = str
			end
		end

		-- use the default defaults file unless overriden
		local defaults = default_defaults
		if item.defaults then
			defaults = prefix .. utils.stringify(item.defaults)
		end

		-- inform users that we're generating a file
		message('INFO','Running pandoc on ' .. source)

		-- import to blocks in the required mode

		local arguments = pandoc.List:new({source})

		if defaults then 
			arguments:extend({'-d', defaults})
		end
		if tempyaml then 
			arguments:extend({'-d', tempyaml_filepath})
		end

		if mode == 'native' then

			arguments:extend({'-t', 'json'})
			local result = pandoc.read(pandoc.pipe('pandoc', arguments, ''), 'json')
			doc.blocks:extend(result.blocks)

		else -- mode = 'raw'

			arguments:extend({'-t', FORMAT})
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
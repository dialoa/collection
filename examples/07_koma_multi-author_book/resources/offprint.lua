--- offprint.lua
-- gather metadata from an import for offprint

-- # Global variables

local utils = pandoc.utils
local system = pandoc.system
local path = require('pandoc.path')
--	% environement variables
local env = {
	working_directory = system.get_working_directory(),
}
env.input_folder = path.directory(PANDOC_STATE['input_files'][1])


return {{
	Meta = function (meta)
		if not (meta.imports and meta.imports[1]) then
			return
		end
		local offprint = meta.imports[1]
		if not offprint.file then
			return
		end

		-- determine path to source file
		local source = utils.stringify(offprint.file)
		if path.is_relative(source) then
			source = path.join({ env.input_folder, source} )
		end

		-- get metadata from source file
		local file = io.open(source, 'r')
		local file_contents = file:read('a')
		file:close()
		local result = pandoc.read(file_contents)

		-- should merge with any metadata provided in offprint field here

		-- place in the doc's metadata `offprint` field
		meta['offprint-meta'] = pandoc.MetaMap(result.meta)

		return meta

	end
}}
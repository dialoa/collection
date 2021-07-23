--- Pass-meta-to-child
-- General procedure to pass a metadata key from the parent doc
-- to a child pandoc process

-- # helper functions

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

-- # Main function

--- save_meta_as_defaults: converts a Meta or MetaMap to a defaults
-- file with a `metadata` field. The defaults file can then
-- be used to import the metadata map into other files.
-- @param filepath string the file path
-- @param map a Meta or MetaMap pandoc AST object
function save_meta_as_defaults(filepath, map)
	-- build empty doc with meta only
	-- with the map in `metadata` field
	local doc = pandoc.Pandoc({}, pandoc.Meta{ metadata = map})

	-- convert to json -> yaml
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


return {{
	Pandoc = function(doc)
		save_meta_as_defaults('temp.yaml', doc.meta)
		os.execute('pandoc chapter.md -d temp.yaml -s -t markdown -o output.md')
	end
}}
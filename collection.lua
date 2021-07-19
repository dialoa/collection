--[[-- # Collection builder - a Lua filter to build
volumes and journal issues in Pandoc's markdown

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2021 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.1
]]

-- # Filter settings

-- # Global variables

local utils = pandoc.utils
local path = require('pandoc.path')

local env = {
	working_directory = pandoc.system.get_working_directory(),
}
env.source_folder = path.directory(PANDOC_STATE['input_files'][1])

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

--- file_exists: checks whether a file exists at a given filepath
-- @param filepath string the filepath at which the file is
local function file_exists(filepath)
  local f = io.open(filepath, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

--- read_from_file: use pandoc.read on a file
-- Returns the pandoc document or false if failed to open the file.
-- @param filepath string filepath from the present working directory
-- @param format string Pandoc format specification
function  read_from_file( filepath, format )

	local fstream = io.input(filepath)

	if fstream then
		local document = pandoc.read(io.read('a'), format)
		io.close(fstream)
		return document
	else 
		return false
	end

end

function citeproc(doc, bib)

    -- https://pandoc.org/lua-filters.html#pandoc.utils.run_json_filter
    -- TODO: set CSL (and other options)
    return pandoc.utils.run_json_filter(
        doc,
        'pandoc',
        {
            '--from=json',
            '--to=json',
            '--citeproc',
            string.format('--bibliography=%s', bib)
        }
    )

end

-- # Filter functions

--- Build Collection
--
--
function build_collection(doc)

for i = 1, #doc.meta.chapters do
        
        local chapter = read_from_file(doc.meta.chapters[i].file)
        local chapter_with_bib = citeproc(chapter, pandoc.utils.stringify(doc.meta.chapters[i].bibliography))
        doc.blocks:extend(chapter_with_bib.blocks)
    
    end
    
    return(doc)	

end

--- Import the metadata from all chapters
-- @param meta document's metadata with a chapters MetaList field
local function import_chapters_meta(meta)
	
	-- prepare the new list
	local chapters = pandoc.List:new()

	for i = 1, #meta.chapters do

		local chapter = {}

		-- if the chapter entry is MetaInlines or MetaBlocks,
		-- we treat it as raw content
		if meta.chapters[i].t == 'MetaInlines' 
			or meta.chapters[i].t == 'MetaBlocks' then

				-- create the type and content fields
				chapter.type = 'Raw'
				chapter.content = meta.chapters[i]

				chapters:insert(pandoc.MetaMap(chapter))

		-- if instead the chapter entry is a MetaMap with a "file" value
		-- we search for the file and merge the metadata		
		elseif meta.chapters[i].t == 'MetaMap' and 
			meta.chapters[i].file then

				local filepath = utils.stringify(meta.chapters[i].file)
				local filepath_from_pwd = path.join({env.source_folder,filepath})
				local format = 'markdown'
				if meta.chapters[i].format then
					format = utils.stringify(meta.chapters[i].format)
				end

				-- get the chapter file metadata if it exists
				if not file_exists(filepath_from_pwd) then
					message('WARNING', 'File not found for entry #' .. i 
						.. 'in chapters.')
				else
					local chapter_doc = read_from_file(filepath_from_pwd, format)
					chapter = chapter_doc.meta
				end

				-- overwrite the metadata from the chapter file with
				-- any meta-data provided in the collection source
				for key,value in pairs(meta.chapters[i]) do
					chapter[key] = value
				end

				-- add the file and type fields
				chapter.file = pandoc.MetaString(filepath)
				chapter.type = 'File'

				chapters:insert(pandoc.MetaMap(chapter))

		-- otherwise warning that we couldn't make sense of the chapter entry
		else

			message('WARNING', 'Entry #' .. i .. " in chapters couldnt be processed.")

		end

	end

	meta.chapters = pandoc.MetaList(chapters)
	return(meta)

end

--- get_options: Read options from document's metadata
local function get_options(meta)
	-- no options to provide at the moment
end


--- Main filter
-- Build a collection provided we have a list of chapters: get
-- options, merge meta-data, build collection. 
return {
	{
		Pandoc = function(doc)
			if doc.meta.chapters and doc.meta.chapters.t == 'MetaList' then
				get_options(doc.meta)
				doc.meta = import_chapters_meta(doc.meta)
				doc.meta.title = doc.meta.collection.title
                		doc.meta.author = doc.meta.collection.editor
				return build_collection(doc)
			else 
				message('WARNING', 'No chapters found, no collection to build.')
			end
		end
	}
}

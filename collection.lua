--[[-- # Collection builder - a Lua filter to build
volumes and journal issues in Pandoc's markdown

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2021 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.1
]]

local utils = pandoc.utils
local system = pandoc.system
local path = require('pandoc.path')

--- filter's environment variables
local env = {
	working_directory = system.get_working_directory(),
}
env.source_folder = env.working_directory .. path.separator .. 
		path.directory(PANDOC_STATE['input_files'][1])

--- list of chapters
local chapters = pandoc.List({})

--- Read a chapter file
-- @param file filename given as relative from the source
local function get_chapter(file)

	local full_filename = env.source_folder .. path.separator .. file

	local fstream = io.input(full_filename)

	if fstream then 

		-- io.read('a') to read all in a string
		local chapter = pandoc.read(io.read('a'))
		io.close(fstream)
		return chapter

	else

		print("Collection filter warning: Chapter " .. file .. " missing or empty.")
		return ({})

	end

end

--- Read options from document's file metadata.
-- @todo: security issue? the chapter filename can be passed on the command line
local function read_options(meta)

	if meta.chapters and meta.chapters.t == 'MetaList' then

		for _,chapteritem in ipairs(meta.chapters) do

			if chapteritem.t == "MetaInlines" then

				local chapter = {
					file = utils.stringify(chapteritem)
				}
				chapters:insert(chapter)

			elseif chapteritem.t == "MetaMap" and chapteritem.file then

				local chapter = {}
				for _,field in ipairs({'file', 'doi'}) do
					if chapteritem[field] then
						chapter[field] = utils.stringify(chapteritem[field])
					end
				end
				chapters:insert(chapter)

			end

		end

	end

end

--- Build Collection
--
--
function build_collection(doc)

	if #chapters > 0 then

		for _,chapter in ipairs(chapters) do

			chapter = get_chapter(chapter.file)

			if chapter.meta and chapter.meta.title then

				print(utils.stringify(chapter.meta.title))

			end

		end


	end

end

--- Main filters
-- Meta will be processed first, we get the chapters list. 
-- Then Pandoc, we add each chapter.
function Meta (meta)

	read_options(meta)

	return meta

end

function Pandoc (doc)

	build_collection(doc)

end

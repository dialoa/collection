--[[-- # Replace headers - a n illustrative Lua filter 
that replaces Level 1 headers with paragraphs in bold 

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2021 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.2
]]

return{{
	Header = function(header)
		return pandoc.Para(pandoc.Strong(header.content))
	end
}}
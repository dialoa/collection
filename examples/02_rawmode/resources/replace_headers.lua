--[[-- # Replace headers - a n illustrative Lua filter 
that replaces headers with paragraphs in bold 
]]

return{{
	Header = function(header)
		return pandoc.Para(pandoc.Strong(header.content))
	end
}}
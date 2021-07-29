--[[-- # Replace headers - a n illustrative Lua filter 
that replaces Level 2 headers with paragraphs in bold 
]]

return{{
	Header = function(header)
		if header.level == 2 then
			return pandoc.Para(pandoc.Strong(header.content))
		end
	end
}}
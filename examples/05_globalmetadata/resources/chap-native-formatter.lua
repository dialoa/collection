--[[-- # Formatter for chapters in native mode - illustrates
	how lua filters can be used to style chapters upon import 
]]

return {{
	Pandoc = function(doc)

		local modified = false

		if doc.meta['global-metadata'] 
			and doc.meta['global-metadata'].volume then
			local vol = pandoc.utils.stringify(doc.meta['global-metadata'].volume)
			doc.blocks:insert(1, pandoc.Para{
				pandoc.Str('The filter understands this is from volume: ' .. vol)})
			modified = true
		end

		if doc.meta.title then
			doc.blocks:insert(1, pandoc.Header(1, pandoc.List:new(doc.meta.title)))
			modified = true
		end

		if modified then 
			return doc
		end

	end
}}
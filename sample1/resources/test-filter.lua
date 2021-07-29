return {{
	Pandoc = function (doc)
		-- add title and author if the output is json
		if FORMAT =='json' then
			
			if doc.meta.author then
				local inlines = pandoc.List:new()
				inlines:insert(pandoc.Strong(pandoc.Str('Authors ')))
				if doc.meta.author.t == 'MetaInlines' then
					inlines:extend(doc.meta.author)
				elseif doc.meta.author.t == 'MetaList' then
					for i = 1, #doc.meta.author do
						inlines:extend(doc.meta.author[i])
						if i < #doc.meta.author then
							inlines:extend({ pandoc.Str(','), pandoc.Space() })
						end
					end
				end
				doc.blocks:insert(1, pandoc.Para(inlines))
			end
			
			if doc.meta.title then
				doc.blocks:insert(1, pandoc.Header(1, pandoc.List:new(doc.meta.title)))
			end

			return doc
		end
	end
}}
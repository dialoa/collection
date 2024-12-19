function Pandoc(doc)
    print(pandoc.write(doc, 'html', {template = pandoc.template.default('html')}))
end
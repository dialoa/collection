test.ast:
	pandoc --standalone --to=native --lua-filter=../collection.lua --output=$@ collection.md

test.html:
	pandoc --to=html5 --standalone --lua-filter=../collection.lua --output=$@ collection.md

test.pdf test.tex:
	pandoc --standalone --variable=documentclass:book --lua-filter=../collection.lua --output=$@ collection.md


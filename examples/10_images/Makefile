DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua expected.html \
	master.md chapter1/chapter1.md chapter2/chapter2.md
	@pandoc -L $(FILPATH)collection.lua master.md -t html \
	--extract-media=media --verbose | $(DIFF) expected.html -

expected.html: $(FILPATH)collection.lua \
	master.md chapter1/chapter1.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -o expected.html \
	--extract-media=media

html: $(FILPATH)collection.lua \
	master.md chapter1/chapter1.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -o out.html \
	--extract-media=media --verbose

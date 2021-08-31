DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua resources/replace_headers.lua \
	resources/chapter-defaults.yaml \
	master.md chapter1.md chapter2.md expected.html
	@pandoc -L $(FILPATH)collection.lua -L resources/replace_headers.lua \
	 master.md -t html --verbose | $(DIFF) expected.html -

expected.html: $(FILPATH)collection.lua resources/replace_headers.lua \
	resources/chapter-defaults.yaml \
	master.md chapter1.md chapter2.md 
	@pandoc -L $(FILPATH)collection.lua -L resources/replace_headers.lua \
	master.md -o expected.html

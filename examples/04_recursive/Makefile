DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua master.md expected.html \
	chapter1.md chapter2/master.md chapter2/section1.md chapter2/section2.md
	@pandoc -L $(FILPATH)collection.lua master.md -t html --verbose \
	 | $(DIFF) expected.html -

expected.html: $(FILPATH)collection.lua	master.md chapter1.md \
	chapter2/master.md chapter2/section1.md chapter2/section2.md
	@pandoc -L $(FILPATH)collection.lua master.md -o expected.html

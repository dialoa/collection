DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua expected.html master.md src1.md src2.md
	@pandoc -L $(FILPATH)collection.lua master.md -t html --verbose | $(DIFF) expected.html -

expected.html: $(FILPATH)collection.lua master.md src1.md src2.md
	@pandoc -L $(FILPATH)collection.lua master.md -o expected.html

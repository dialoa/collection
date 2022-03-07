DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua expected.tex master.md src1.md src2.md
	@pandoc -L $(FILPATH)collection.lua master.md -s -t latex --verbose | $(DIFF) expected.tex -

expected.tex: $(FILPATH)collection.lua master.md src1.md src2.md
	@pandoc -L $(FILPATH)collection.lua master.md -s -o expected.tex

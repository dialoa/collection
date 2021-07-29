DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua master.md chapter1.md chapter2.md \
	expected.html expected_offprint.html
	@pandoc -L $(FILPATH)collection.lua master.md -t html --verbose | $(DIFF) expected.html -
	@pandoc -L $(FILPATH)collection.lua master.md -M offprint=2 \
	-t html --verbose | $(DIFF) expected_offprint.html -

expected.html: $(FILPATH)collection.lua master.md chapter1.md chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -o expected.html

expected_offprint.html: $(FILPATH)collection.lua master.md chapter1.md chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -M offprint=2 -o expected_offprint.html

DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test
test: $(FILPATH)collection.lua master.md chapter1.md chapter2.md expected.html
	@pandoc -L $(FILPATH)collection.lua master.md -t html --verbose \
	 | $(DIFF) expected.html -

.PHONY: generate
generate: expected.html

expected.html: $(FILPATH)collection.lua	master.md chapter1.md chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -o expected.html

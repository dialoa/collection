DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test
test: $(FILPATH)collection.lua expected.html resources/chapter.yaml \
	master.md chapter1/chapter1.md chapter2/chapter2.md
	@pandoc -L $(FILPATH)collection.lua master.md -t html --verbose | $(DIFF) expected.html -

.PHONY: generate
generate: expected.html 

expected.html: $(FILPATH)collection.lua resources/chapter.yaml \
	master.md chapter1/chapter1.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -o expected.html

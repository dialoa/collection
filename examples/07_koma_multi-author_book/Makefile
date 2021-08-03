DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua expected.latex resources/book.yaml resources/chapter.yaml \
	resources/book.latex resources/chapter.latex \
	master.md chapter1/chapter1.md chapter2/chapter2.md
	@pandoc -L $(FILPATH)collection.lua master.md -d resources/book.yaml -t latex --verbose \
	| $(DIFF) expected.latex -

expected.latex: $(FILPATH)collection.lua resources/book.yaml resources/chapter.yaml \
	resources/book.latex resources/chapter.latex \
	master.md chapter1/chapter1.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -d resources/book.yaml -o expected.latex

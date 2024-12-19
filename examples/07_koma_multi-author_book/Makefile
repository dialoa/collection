DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test
test: test-book test-offprint

.PHONY: test-book
test-book: $(FILPATH)collection.lua expected-book.tex resources/book.yaml resources/chapter.yaml \
	resources/book.latex resources/chapter.latex README.md \
	master.md chapter1/chapter1.md chapter2/chapter2.md
	@pandoc -L $(FILPATH)collection.lua master.md -d resources/book.yaml -t latex --verbose \
	| $(DIFF) expected-book.tex -

.PHONY: test-offprint
test-offprint: $(FILPATH)collection.lua expected-offprint.tex \
	resources/offprint.yaml resources/chapter.yaml \
	resources/offprint.latex resources/chapter.latex resources/offprint.lua \
	master.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -d resources/offprint.yaml \
		-M offprint=2 -t latex --verbose | $(DIFF) expected-offprint.tex -

.PHONY: generate
generate: expected-book.tex expected-offprint.tex

expected-book.tex: $(FILPATH)collection.lua resources/book.yaml resources/chapter.yaml \
	resources/book.latex resources/chapter.latex README.md \
	master.md chapter1/chapter1.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -d resources/book.yaml -o expected-book.tex

expected-offprint.tex: $(FILPATH)collection.lua resources/offprint.yaml resources/chapter.yaml \
	resources/offprint.latex resources/chapter.latex resources/offprint.lua \
	master.md chapter2/chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -d resources/offprint.yaml \
		-M offprint=2 -o expected-offprint.tex

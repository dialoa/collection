DIFF ?= diff --strip-trailing-cr -u
FILPATH ?= ../../

.PHONY: test

test: $(FILPATH)collection.lua master.md chapter1.md chapter2.md \
	expected-collection.html expected-chap1.html expected-chap2.html \
	resources/collection-defaults.yaml resources/chapter-template.html \
	resources/offprints-defaults.yaml resources/offprint-template.html
	@pandoc -L $(FILPATH)collection.lua master.md -t html --verbose \
	 | $(DIFF) expected-collection.html -
	@pandoc -L $(FILPATH)collection.lua master.md -M offprint-mode=1 \
	-t html --verbose | $(DIFF) expected-chap1.html -
	@pandoc -L $(FILPATH)collection.lua master.md -M offprint-mode=2 \
	-t html --verbose | $(DIFF) expected-chap2.html -

expected-collection.html: $(FILPATH)collection.lua master.md \
	resources/collection-defaults.yaml resources/chapter-template.html \
	chapter1.md chapter2.md 
	@pandoc -L $(FILPATH)collection.lua master.md -o expected-collection.html

expected-chap1.html: $(FILPATH)collection.lua master.md chapter1.md \
	resources/offprints-defaults.yaml resources/offprint-template.html 
	@pandoc -L $(FILPATH)collection.lua master.md -M offprint-mode=1 \
	 -o expected-chap1.html

expected-chap2.html: $(FILPATH)collection.lua master.md chapter2.md \
	resources/offprints-defaults.yaml resources/offprint-template.html 
	@pandoc -L $(FILPATH)collection.lua master.md -M offprint-mode=2 \
	 -o expected-chap2.html

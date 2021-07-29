---
title: My collection
imports:
- chapter1.md
- chapter2.md
---

# Introduction

This introduction is written in the master document itself. The imported files are placed after it.

This collection illustrates the simplest use of the filter. By default chapters are imported in native mode. Without defaults (in particular, filters) applied to the imported chapter, using `collection.lua` is overkill: we could have achieved the same by simply running `pandoc master.md chapter1.md chapter2.md -o expected.html`. Using `collection.lua` is less efficient, since Pandoc is executed on each chapter as well as on the entire document. 

The Makefile executes two commands, one that generates the entire collection and one that generates an offprint of the second item in our `imports` list:

```bash
pandoc -L ../../collection.lua master.md -o expected.html
pandoc -L ../../collection.lua master.md -M offprint=2 -o expected_offprint.html
```

Note that the body text of `master.md` is printed in all outputs (collection and offprints). It is suited for a cover, not a preface.
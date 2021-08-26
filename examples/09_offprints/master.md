---
title: My collection
lang: en
collection: 
    defaults: resources/collection-defaults
    mode: raw
    pass: [title, lang]
offprints: 
    defaults: resources/offprints-defaults
    mode: raw
    pass: [title, lang]
imports:
- chapter1.md
- chapter2.md
---

# Introduction

This illustrates the offprint mode. We generate one output for the 
full collection and one for each chapter. Different defaults files are used
for the collection and offprints. To do this we run:

```bash
pandoc -L collection.lua master.md -o expected-collection.html
pandoc -L collection.lua master.md -M offprint-mode=1 expected-chap1.html
pandoc -L collection.lua master.md -M offprint-mode=1 expected-chap2.html
```

In this example the defaults file for the collection generates a full
standalone document while the one for offprints a body only. 

Note that any text in the master file is included at the beginning
of each offprint.
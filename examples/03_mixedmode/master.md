---
title: My collection
collection:
    mode: raw
imports:
- file: chapter1.md
  mode: native
- chapter2.md
---

# Introduction

This example illustrates mixed mode imports:

* the document's default mode is `raw`, so chapters are imported in `raw` otherwise specified.
* the first chapter's mode is specified as `native`. 

So the first chapter is imported in native, the second in raw. To verify that this is the case, we apply a filter that converts level 2 headings to paragraphs with strong text. As you can see the filter worked on the first chapter (imported in native) but not the second (imported in raw).
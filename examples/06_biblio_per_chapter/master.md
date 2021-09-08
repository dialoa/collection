---
title: My collection
collection:
    mode: native
    isolate: true
    isolate-prefix-pattern: 'chap-%d-'
    defaults: resources/chapter.yaml
imports:
- file: chapter1/chapter1.md
- chapter2/chapter2.md
---

# Introduction

This is a simple per-chapter bibliography collection, using Citeproc (Pandoc's built-in bibliography engine). In `chapter.yaml` we specify that the `citeproc` filter must be run on each chapter before importing. 

The **isolate** option allows us to avoid link conflicts across chapters. 
Here both chapters cite  `@dummettFregePhilosophyLanguage1981`. Citeproc generates the same identifier for this reference in chapter 1's bibliography and in chapter 2's bibliography. Normally this would have the consequence citation links for this reference are wrong in chapter 2: they would end up linking to chapter 1's bibliography entry. With **isolate** the `collection` filter passes each chapter through an (internal) `isolate` filter before importing it. The filter is run last (after any other filter applied to the chapter), and adds a unique prefix to all identifiers and internal links in that chapter. 

* **isolate** ensures that there's no duplicate link targets across chapters (in bibliographies, headings, etc.)
* but **isolate** prevents one from having cross-references across chapters. 

**Isolate** can be set on a per-import basis, and works both in `raw` and `native` mode. (Thus unlike Pandoc's `--id-prefix` flag, it avoids conflicts 
even when the output format is other than HTML or DocBook.) 

It is possible to specify the pattern used to add prefixes to identifier,
with the `isolate-prefix-pattern` option. The 
pattern is a lua pattern containing `%d`; the `%d` element will be replaced by the number of the imported file. For instance `chap-%d%-` will give the 
prefixes `chap-1-`, `chap-2-` and so on. The default pattern is `c%d-`: `c1-`, `c2-`, .... 
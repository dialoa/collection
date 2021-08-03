---
title: My collection
editor: Jane E. Doe
imports:
- chapter1/chapter1.md
- chapter2/chapter2.md
---

# Introduction

This is an example of a multi-author collection in the KOMA book style. Custom
pandoc templates are used to generate the book and each chapters (`book.latex` 
and `chapter.latex`). The book templates includes alteration to KOMA's `scrbook`
class to:

* provide an abstract to each chapter,
* generate tables of contents whose entries include the author names as
well as the title,
* provide additional commands to print author names in the page headings. 

Each chapter has its own bibliography. Citation links are isolated: even though both chapters cite the same bibliography entry, its citations in each chapter link to the bibliography of that chapter. 

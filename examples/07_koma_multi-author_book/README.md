---
title: Introduction
---

This is an example of a multi-author collection using the KOMA script book class (a versatile LaTeX class with advanced typography features). Custom pandoc templates are used to generate the book and each chapters (`book.latex` 
and `chapter.latex`). The book templates includes alteration to KOMA's `scrbook`
class to:

* provide an abstract to each chapter,
* generate tables of contents whose entries list both author and title
* generate PDF bookmarks with both author and title
* provide additional commands to print author names in the page headings. 

Each chapter has its own bibliography. 

Citation links are isolated: even though both chapters cite the same bibliography entry, its citations in each chapter link to the bibliography of that chapter. 

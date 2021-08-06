---
title: Passing metadata
author: Jane Doe
global-metadata:
    globalkey: This is a global value
metadata:
    childkey: This is a child key
    header-includes: test
collection:
    mode: raw
    gather: [header-includes, bibliography]
    pass: [css, header-includes]
    globalize: [author,bibliography]
    defaults:
        number-sections: true
bibliography: 
- data1.bib
- data2.bib
imports:
- file: src1.md
  mode: native
  metadata:
    doi: doi12315
    author: Jane Doe
- src2.md
---

# Passing metadata

This example demonstrates options to pass metadata around between master and source files.
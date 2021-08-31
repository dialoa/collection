---
title: My collection
collection:
    mode: raw
    defaults: resources/chapter-defaults.yaml
imports:
- chapter1.md
- chapter2.md
---

# Introduction

This document imports chapters in Raw mode. This means the chapters are converted to whatever output format is targeted (e.g., html) before being imported. 

To illustrate this, we apply a Lua filter to the main document. The filter replaces every heading it finds with a pararaph with bold text. As you can see, the first heading of this document has been replaced but the others haven't. That is because the first heading is part of the `master.md` file, which processes parses to its native format (hence recognizes its headers as headers), while the other headings are imported in raw output format (e.g., html or latex code) that Pandoc doesn't recognize as header, bullet list, etc. anymore. 
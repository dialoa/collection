---
title: "Collection - generating collections with Pandoc"
author: "Julien Dutant"
---

**WORK IN PROGRESS**. *The filter is not functional yet.*

A Lua filter for Pandoc to build multi-authored collections
(journals, monographs) from markdown source to LaTeX/PDF, epub, html,
JATS XML.

# Description

The filter is a run on a *master file* to generate a collection for a bunch of *source files*. Pandoc already offers simple ways to combine various files into one document. However this filter provides much more control of how sources are manipulated or formatted before their inclusion in a main document. That is particularly useful when we want to keep separate the metadata and material of the sources from those of the master document, and yet combine them when converting each source to the desired output format. It was designed with academic journals and multi-author monographs in mind. 

The master file is a markdown document that normally consists of a YAML metadata block, for instance:

```yaml
---
title: Journal of Serious Studies 
author: Jane Doe
global:
  volume: 4
  issue: 1
collection: 
  mode: raw
  defaults: chapter-style.yaml
imports:
- file: preface.md
  defaults: preface-style.yaml
  mode: native
- file: 'chapter1/source.json'
  format: json
- file: 'chapter2/source.md'
---
```

The overall process is:

* source files + global metadata `--`(import defaults)`-->` native or raw elements `--`(book defaults)`-->` output

For an illustration, suppose you run the filter on the document above (saved as `master.md`) with the command:

```bash
pandoc --lua-filter collection.lua -defaults=book.yaml master.md -o book.pdf
```

The filter will use the fields `global`, `collection` and `imports` to build a collection. The filter will build a main document out of all the files mentioned in `imports` in the order listed. The steps are as follows:

1. The filter runs Pandoc on each file. In the pandoc call, the `global` metadata is combined with that file's metadata (replacing any `global` field it may have) and applies a *defaults* file if provided. Here the defaults file `chapter-style.yaml` is applied to each import except `preface.md` that uses a different defaults file `preface-style.yaml`. Defaults files allow you to specify options, filters and templates to be applied to the file before integration. Thus any amount of formatting based on a combination of the file's metadata and the global metadata can be achieved before importing the file.
2. For each file, the result is inserted in the main document. The result can be either in Pandoc's internal format (`native`) or already in whichiver format we're targetting (`raw`). Here we're importing the preface in `native` mode, but the chapters will be inserted in `latex`, the output format Pandoc generates to get PDFs. Each mode has its specific advantages:
  a. The raw mode allows you to format chapters with pandoc templates. Pandoc templates are relatively easy ways of formatting the output. They can use the metadata passed from `master.md` (`$global.volume$` will print out `4`) and the metadata of the source file itself. 
  b. The native mode allows you to apply Lua filters to the combined document, after imports. Because the material imported is still Pandoc's internal format, it is readily available for further manipulation by a Lua filter applied to the combined document. That is, the filter will still recognize which elements were quotes, headers, links etc. and modify them easily. By contrast, filters applied to the whole document won't normally touch or peer into material that is already in output format. 
3. Pandoc then converts the combined document into output format. It applies any options or defaults provided. Here we specicy a defaults file `book.yaml` that can speciy what options, filters, templates Pandoc should use when generating the output document. 

The filter uses four metadata fileds: 

* `collection` (optional) species options for building the collection: a (default) mode for importing chapters, a (default) defaults file to apply when importing chapters, and others. 
* `imports` that gives a list of files to be imported, as well as any file-specific import options, e.g. what import mode or defaults to use for a given file.
* `global` (optional) some metadata that we want to pass to each file before import. This metadata can then be used by filters or templates files to style the elements appropriately. For instance, the defaults file for imported chapters can specify a template `chapter.latex` that uses the metavariables `volume` and `issue` to display volume and issue numbers in each chapter. 
* `offprint` (optional) to select one import file for offprint

# Basic usage

Produce the whole collection as `book.pdf` with the defaults pandoc settings given in `book.yaml`:

```bash
pandoc -L collection.lua master.md -d book.yaml -o book.pdf
```

Produce an offprint of the second item in `imports` of `master.md`, using the defaults `offprint.yaml`:

```bash
pandoc -L collection.lua master.md -d offprint.yaml -offprint=2 -o chapter1.pdf
```


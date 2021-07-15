---
title: "Collection - generating collections with Pandoc"
author: "Julien Dutant"
---

**WORK IN PROGRESS**. *The filter is not functional yet.*

A Lua filter for Pandoc to build multi-authored collections
(journals, monographs) from markdown source to LaTeX/PDF, epub, html,
JATS XML.

# Usage

The filter is a run on a *master file* to generate a collection.
The master file is a markdown document, but only consists of a
YAML metadata block:

```yaml
---
title: Journal of Serious Studies 
author: Jane Doe 
chapters:
- file: preface.md
- 'Copyright (c) Jane Doe 2021'
- file: 'chapter1/source.json'
  format: json
- file: 'chapter2/source.md'
---
```

The `chapters` field is a list of elements; the collection will be built
from them in that order. Elements can be content or metadata referencing
a file. Content is included as is; files are imported. The filter gets 
each imported file's metadata, in particular title, author,
bibliography, and generates a collection. 

## Design

* you will process each local document with its updated metadata, convert
  it to the desired output format (including citeproc biblio) and 
  insert it in master as a RawBlock. 
* qu: the updated metadata isn't available in the chapter source document. 

## Terminology

* *present working directory*. The folder at which the user is located
   when they execute pandoc. 
* *collection source*. The markdown document on which Pandoc is run to
   generate the collection.
* *collection source folder*. The folder containing the collection
   source.
*  

## Background technical details

## Issue

When to apply the filters to a document?

* Suppose you get the 
 document metadata's first. Then you process it again with filters, 
 and these filters modify its metadata (header-includes). What do 
 you do? ANS: you only care about header-includes, and you get 
 those at the second, processing time.
* Suppose you process the document first. What if your master file 
  specifies an alternative title or author for that document? (Or a 
  first page?) the 
  processor will use the metadata in the chapter file only. 

### Paths in Pandoc

* `pandoc.system.get_working_directory()` the present working
  directory, i.e. folder at which the user was located when they
  launched pandoc. On MacOS, an absolute path.
* `PANDOC_STATE.input_files` list of input filepaths from the command
  line.
* `PANDOC_STATE.resource_path` Path to search for resources like included images (List of strings). By default just has `.` (the present working directory).
* `PANDOC_STATE.source_url` Absolute URL or directory of first source file.
* `PANDOC_STATE.user_data_dir` Directory to search for data files (string or nil)
* `PANDOC_STATE.output_file` output filepath or nil. 
* `PANDOC_SCRIPT_FILE`. The name used to involve the filter, can be used
  to find resources at locations relative to the filter itself.

 

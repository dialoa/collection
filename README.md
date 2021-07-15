---
title: "Collection - generating collections with Pandoc"
author: "Julien Dutant"
---

A Lua filter for Pandoc to build multi-authored collections
(journals, monographs) from markdown source to LaTeX/PDF, epub, html,
JATS XML.

*Work in progress, starting with LaTeX and HTML output*.

# Usage

The filter is a run on a *collection source* to generate a collection.
The collection driver is a markdown document, but only consists of a
YAML metadata block:

```yaml
---
title: Journal of Serious Studies 
author: Jane Doe 
chapters:
- file: preface.md
- '\mainmatter'
- file: 'chapter1/source.json'
  format: json
- file: 'chapter2/source.md'
---
```

The filter gets each chapter's metadata, in particular title, author,
bibliography, and generates a collection. 

## Terminology

* *present working directory*. The folder at which the user is located
   when they execute pandoc. 
* *collection source*. The markdown document on which Pandoc is run to
   generate the collection.
* *collection source folder*. The folder containing the collection
   source.
*  

## Background technical details

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

 

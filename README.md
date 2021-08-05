---
title: "Collection - generating collections with Pandoc"
author: "Julien Dutant"
---

A Lua filter for [Pandoc](https://pandoc.org) for building complex multi-part documents, such as academic journalss, multi-author collections, or documents with multiple styles and multiple output formats. 

# Introduction

Call a *collection* is a single document build for from document parts in multiple source files. [Pandoc](pandoc.org) can already build collections:

```bash
pandoc source1.md source2.md -o collection.html
```

Its ability is limited though: sources must be specified on the command line, they are concatenated as if in a single markdown document and their metadata (if any) is merged.^[The merging behaviour is simple: if two sources have the same key the latter one prevails. This is sometimes counterintuitive, e.g. with the `header-includes` field. See [here](https://github.com/jgm/pandoc/issues/5881) and [here](https://groups.google.com/g/pandoc-discuss/c/N6WhlmSPXbY) for instance.] The only option is [`--file-scope` option](https://pandoc.org/MANUAL.html#option--file-scope) that ensures that footnotes with the same name in different files work as excepted, but prevents links across files (this is like the `isolate` option of this filter). 

This filter provides advanced control on building collections. 

1. *Master files* are used to describe collections. These are easier to read and edit than command lines or Makefiles. 
2. *Pandoc is run on source files before import* (default, can be deactivated on a per-source basis). This means that specific Pandoc settings ([defaults](https://pandoc.org/MANUAL.html#default-files), [templates](https://pandoc.org/MANUAL.html#templates) and [filters](https://pandoc.org/MANUAL.html#option--filter)) can be applied to sources before import, and different ones to different sources.
3. *Metadata can be passed from the main document to its sources, and gathered from the sources into the main document*. This allows styling parts in light of the main document (e.g., displaying volume information in chapters) and gathering information from the parts into the main (e.g., gathering bibliographic database from the sources or `header-includes` blocks). 
4. *Recursive* collection-building is possible. That is, you can build collections of collections of ... collections of sources. 
5. An *offprint* mode is provided that outputs only one of the collection's sources. This feature is meant for academic journals, to allow you to output an entire issue as well as each article separately. 

A note of the filter's design principles: 

1. *Power*. We try to cater to broad range of workflows. You can convert sources to output before or after importing them into the main document; convert some before and others after; apply different Pandoc defaults and filters to different parts and to the whole document. You can pass metadata from the master file to the sources, and different metadata to different sources. You can use the filter recursively to build collections of collections.
2. *Freedom*. The filter doesn't constrain your folder structure, your input or output formats, how you handle citations, etc. 
4. *Pure Pandoc*. Only Pandoc should be needed to generate a collection. This means that once a set-up is designed (collection options, templates and filters), people can use it to build collection without the need to master any technology beyond the basic terminal commands to launch Pandoc. 
5. *Pandoc skills required*. No ready-made set-ups are included, at this stage at least. You'll have to build your own settings. To design a collection set-up typically you'll need to ypically need to be familiar with Pandoc's defaults and metadata blocks (easy) and possibly write Pandoc templates and/or Lua filters (harder). 
6. *Extensibility*. The filter is meant to play well with pretty much any other Pandoc-based tool you might want to use, e.g. filters, templates, defaults.^[Exception: at this stage it can only run `pandoc` on source files, so you couldn't run a pandoc wrapper on them instead.] The code is well commented so you can modify it for your own purposes. 
7. *Speed is secondary*. Power and clear design is priviledged over speed. Since the filter typically runs Pandoc on each source (and sometimes twice, if it needs to read their metadata), a document with 10 sources will be processed about 10 times slower than if you used Pandoc's own file concatenation. That being said, Pandoc is fast, so the extra time is negligeable when compared to e.g. the LaTeX run needed to output a PDF. I recommend running it with Pandoc's `--verbose` option to follow the building progress and using the *offprint* mode to print out one source only when you're working on one part only. 

# Installation

[Pandoc](https://pandoc.org) must be [installed on your system](https://pandoc.org/installing.html). 

You only need the filter file `collection.lua`. (Here is a [direct link](https://raw.githubusercontent.com/jdutant/collection/main/collection.lua).) Save it somewhere in your system, e.g. in your collection's top folder.

If you save it in a subfolder `filters` of Pandoc's user data directory, you won't need to provide its path in your Pandoc commands. See [Pandoc's manual](https://pandoc.org/MANUAL.html#option--data-dir) for more on user data directories in Pandoc. 

# Basic usage

## Commands

Collections are built  by applying the filter to a master file, e.g.:

```bash
pandoc -L collection.lua master.md -o book.pdf
```

This turns the collection described in `master.md` into `book.pdf`. The `-L` flag is an alias for `--lua-filter` and `-o` for `--output`. If you're new to Pandoc: by and large the order of arguments don't matter, so the following works just as well: 

```bash
pandoc --lua-filter collection.lua --output book.pdf master.md
```

The above will only work if `master.md` is located in the folder where you run the command, and if Pandoc can find `collection.lua`. With this command Pandoc will find `collection.lua` if it's in the same folder, or in a `filters` subfolder of your [user data directory](https://pandoc.org/MANUAL.html#option--data-dir)). Otherwise you need to specify paths:

```bash
pandoc -L path/to/collection.lua path/to/master.md -o output.pdf
output.pdf 
```

Replacing `path/to/` with suitable paths (if relative, from the directory in which you're executing these commands) for the `collection.lua` and `master.md` files, respectively. For instance, if your terminal is located at a folder with two subfolders, `mycollection` containing the master file `master.md` and `resources` containing the filter file `collection.lua`, and your want to output a file `book.html` in the present folder, you should run: 

```bash
pandoc -L resources/collection.lua mycollection/master.md -o book.html
```

You can use any other Pandoc option to control your collection output. For instance, you'll typically want a standalone document, with the `--standalone` or `-s` option:

```bash
pandoc -L collection.lua -s -o book.pdf master.md
```

A good practice is to place your options in a [Pandoc *defaults* file](https://pandoc.org/MANUAL.html#default-files). For intsance, saving the following a `book.yaml` next to `master.md`:

```yaml
standalone: true
pdf-engine: lualatex
filters:
- collection.lua
```

And run the command (`-d` is short for `--defaults`):

```bash
pandoc -d book.yaml master.md -o book.pdf
```

This will apply the defaults specified to `master.md`: standalone mode, use the LuaLaTeX pdf engine when producing PDFs, and apply the `collection.lua` filter. 

## Master files

A master files is a markdown file with a [metadata block in `yaml` format](https://pandoc.org/MANUAL.html#extension-yaml_metadata_block). Any text in the body of the document will appear before the imported sources. The only metadata field required is a `imports` field specifying a list of sources:

```markdown
---
title: My collection
author: Jane Doe 
imports:
- chapter1.md
- chapter2.md
---

# Introduction

This introduction section will appear at the beginning of the collection, followed by the content of `chapter1.md` and `chapter2.md`.
```

The metadata block in `YAML` format is between `---` and `---`. The `imports` field specifies source files, to be included in the order listed. The source files are listed in that field, each item in a line starting with a hyphen `- ` (aligned below `imports`, or indented if you wish).

If sources files are located in other folders, specify their path relative to the master file (or an absolute path). For instance, if the folder containing `master.md` has subfolders for each source, the master file may look like this:

```yaml
---
title: My collection
author: Jane Doe 
imports:
- introduction/source.md
- chapter1/source.md
- chapter2/source.md
---
```

By default source files are processed by Pandoc before import. This means that footnotes won't clash: if each `chapter1.md` and `chapter2.md` have a footnote named `[^1]` or `[^idea]` the links will still be correct. Internal links across chapters are still possible, e.g. `as we saw [here](#importantpoint)` in `chapter2.md` can link to `[Point 1]{#importantpoint}` in `chapter1.md`. For more details and options, see [below on the building process](#the-building-process).

The filter also makes use of these metadata fields (and their aliases) if present. (If you're not familiar with the term "map", see the YAML primer below.)

* `collection`: a map of options to build the collection and offprints.
* `offprint-setup`: a map of additional options to build offprints (not used when building a collection). 
* `collection-setup`: a map of additional options to build collections (not used when building an offprint.)
* `child-metadata` (alias `metadata`): metadata passed to the sources before import. If building a collection of collections, this is only passed to the immediate sources of the collection, not the sources of the sources. 
* `global-metadata` (alias `global`): metadata passed to the sources in a `global-metadata` field. When building recursively (collections of collections ... of collections of sources), this trickles down to the sources of the sources. 
* `offprint`. Normally used on the command line only, to switch to offprint mode. 
* ... and other fields of the form `collection-...` that provide aliases for collection options. These are easier to use  

Here is an example of master file using the `collection` field to specify options: 

```yaml
---
title: Journal of Serious Studies 
editor: Jane Doe
collection: 
  mode: raw
  defaults: chapter-style.yaml
imports:
- introduction/source.md
- chapter1/source.md
- chapter2/source.md
---
```

Here two collection options are specified: `defaults` and `mode`. Note the indentation needed to indicate that they are sub-fields of `collection`. (The former specifies a Pandoc defaults file to process the sources before import, the second specifies the `raw` import mode in which sources are converted to output before being imported in the main document. These options and others are explained in more detail below).

# YAML primer

The filter heavily uses (a simple subset of) [YAML syntax](https://yaml.org/spec/1.2/spec.html). That is the syntax of metadata blocks in Pandoc's markdown and of Pandoc's default files. Here is a primer.

A YAML *map* or *dictionary* is a series of `key:value` pairs. Each start on a new line. Keys are labels. Simple values can be strings, numbers or boolean (`true` or `false`):

```yaml
age: 12
hobby: knitting
registered: true
tag-phrase: go steady, go far
```

The metadata block in Pandoc markdown is a map, for instance.

A YAML *list* is a list of `- value` items. Each starts on a new line with a hyphen. Again, simple values can be strings, numbers, booleans:

```yaml
- sax
- alto sax
- 1
- true
```

But values need not be simple. They can themselves be maps or lists. Here is a list of three maps:

```yaml
- file: chapter1.md
  format: markdown
  size: 10
- file: chapter2.md 
  url: sources.com/folder/
  template: chapter.latex
- source: book
  author: Jane Doe
  year: 2015
```

Note the indentation: each line of the first map starts at the same point. The following wouldn't be processed correctly:

```yaml
- file: chapter1.md
format: markdown
```

because `format` wouldn't be taken as part of the list item. 

Here is a map with two keys, where the value of each key is a list.

```yaml
authors:
- Jane Doe
- Joe Dane
editors:
- Al Mel
- Mel Al
```

The list items must start at the line below the key, and be at least as indented as the key. The following would work well too:

```yaml
authors:
  - Jane Doe
  - Joe Dane
editors:
  - Al Mel
  - Mel Al
```

But not the following:

```yaml
  authors:
- Jane Doe
- Joe Dane
  editors:
- Al Mel
- Mel Al
```

Here `- Jane Doe` is left of `authors:`, so isn't processed as its value. 

Here is a map with two keys, `plant` and `animal`. The value of `plant` is itself a map with three keys and the third key's value is a list. The value of `animal` is a map with two keys (`features`, `habitat`) whose values are themselves maps:

```yaml
plant:
  species: rose
  colour: white
  months:
  - april 
  - march
animal:
  features:
    ears: long
    legs: 4
  habitat:
    summer: sea
    winter: mountain
```

That's basically all you need for using this filter: understand  maps, lists, and how to use indentation to use them as values of other maps and lists. 

While we're at it, a couple of further features useful in Pandoc's markdown. 
If a string value contains a colon, put it in single or double quotes. If it contains single quotes, put it in double quotes or vice versa. If it contains both, escape them with `\`.

```
title: "My book: a journey"
author: 'John "Big J" Johnson'
editor: Jane Doe
publisher: The \"Hip \'Press
```

The last kind of value besides maps, lists, strings, numbers and booleans are *text blocks*. These are entered by placing `|` where the value would have been, and entering the block in the lines below, each line starting with at least two spaces of indentation. Here is a map with one key whose value is a block of text:

```
thanks: |
  I would like to thank the Earth, oxygen, water,
  and other building blocks of life.
```

Here is a list whose two items are blocks of text:

```
- |
  I have long
  waited for a
  train.
- |
  I have also
  waited
  for you.
```


No need to escape colons and quotes in text blocks. Text blocks can contain empty lines. 

Note that Pandoc reads strings and text blocks as markdown, so markdown formatting (`*emphasis*`, `[link](http://theaddress.org/)`) is allowed.  

# The building process

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

# Advanced usage

## Combining with other filters

If you're applying other Pandoc filters to your master file, `collection.lua` should normally be applied first. This will import all the sources in your document before the other filters are applied to it, which is probably what you want. To do this place `collection.lua` first on the command line:

```bash
pandoc -L collection.lua -L myfilter.lua master.md -o book.pdf
```

Or put it first in your collection default file:

```
filters:
- collection.lua
- myfilter.lua
```

If you specify filters both on the command line and a default file, the command lines one are ran first. Thus you can specify your additional filters in the defaults file and call `collection` from the command line, but not the other way round. 

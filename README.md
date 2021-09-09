---
title: "Collection - generating collections with Pandoc"
author: "Julien Dutant"
---

**WARNING**: this filter is in progress. Functionality may and will change. 

Collection for [Pandoc](https://pandoc.org) is a [Pandoc Lua filter]
(https://pandoc.org/lua-filters.html) for building complex multi-part
documents such as academic journalss, multi-author collections, or
documents with multiple styles and multiple output formats. 

# Introduction

Call a *collection* is a single document build for from document parts
in multiple source files. [Pandoc](pandoc.org) can already build
collections:

```bash 
pandoc source1.md source2.md source3.md -o collection.html
```

This process is limited though: sources must be specified on the
command line, they are concatenated as if in a single markdown
document and their metadata (if any) is merged.^[The merging
behaviour is simple: if two sources have the same key the latter one
prevails. This is sometimes counterintuitive, e.g. with the
`header-includes` field. See [here]
(https://github.com/jgm/pandoc/issues/5881) and [here]
(https://groups.google.com/g/pandoc-discuss/c/N6WhlmSPXbY) for
instance.] The only option is [`--file-scope` option]
(https://pandoc.org/MANUAL.html#option--file-scope) that ensures that
footnotes with the same references in different markdown files work
as excepted, but prevents links across files (similar to Collection's
`isolate` option). 

Collection provides advanced control on building collections. 

1. *Master files* are used to describe collections. These are easier
to read and edit than command lines or Makefiles. 2. *Pandoc is run
on source files before import* (default, can be deactivated on a
per-source basis). This means that specific Pandoc settings (
[defaults](https://pandoc.org/MANUAL.html#default-files), [templates]
(https://pandoc.org/MANUAL.html#templates) and [filters]
(https://pandoc.org/MANUAL.html#option--filter)) can be applied to
sources before import, and different ones to different sources.
3. *Metadata can be passed from the main document to its sources, and
gathered from the sources into the main document*. This allows
styling parts in light of the main document (e.g., displaying volume
information in chapters) and gathering information from the parts
into the main (e.g., gathering bibliographic database from the
sources or `header-includes` blocks). 4. *Recursive*
collection-building is possible. That is, you can build collections
of collections of ... collections of sources. 5. An *offprint* mode
is provided that outputs only one of the collection's sources. This
feature is meant for academic journals, to allow you to output an
entire issue as well as each article separately. 

Collection's design principles: 

1. *Power*. Cater for a broad range of workflows. You can convert
sources to output before or after importing them into the main
document; convert some before and others after; apply different
Pandoc defaults and filters to different parts and to the whole
document. You can pass metadata from the master file to the sources,
and different metadata to different sources. You can use the filter
recursively to build collections of collections. 2. *Freedom*. Don't
constrain the user's folder structure, choice of input or output
formats, styles, citation handling, etc. 4. *Pure Pandoc*. Handle all
with Pandoc. Once a collection set-up is designed, people can use it
without the need to master any technology beyond the simplest Pandoc
commands. No need for them to master GitHub, Python scripts,
Makefiles etc. 5. *Pandoc skills required*. No ready-made setups
provided (at this stage). Designing a collection set-up typically
requires familiarity with Pandoc's defaults and metadata blocks
(easy) and possibly Pandoc templates and/or Lua filters
(harder). 6. *Pandoc ecosystem*. Maximize compatibility with existing
Pandoc-based tools such as [lua filters]
(https://github.com/pandoc/lua-filters), [other filters]
(https://github.com/jgm/pandoc/wiki/Pandoc-Filters), [templates]
(https://github.com/jgm/pandoc/wiki/User-contributed-templates), and
[more](https://github.com/jgm/pandoc/wiki). , Exception: at this
stage it can only run `pandoc` on source files, so you couldn't run a
pandoc wrapper on them instead. The code is well commented so you can
modify it for your own purposes. 7. *Speed is secondary*. Priviledge
power and clear design over speed. This is mostly a production tool,
for final output. At writing stage the offprint mode can be used for
faster output of parts of the document. When building a large
document, the `--verbose` mode allows you to follow building
progress. 

On speed. Collection typically runs Pandoc on each source
(sometimes twice, if it needs to read their metadata) and needs to
write temporary files to pass metadata around. Hence generating a
document with 10 sources is about 10 times slower than Pandoc's basic
collection building mechanism. That being said, Pandoc is fast, so
the extra time is negligeable compared to e.g. compared to e.g. the
LaTeX run needed to output a PDF.

# Installation

[Pandoc](https://pandoc.org) must be [installed on your system]
(https://pandoc.org/installing.html). 

You only need the filter file `collection.lua`. (Here is a
[direct link]
(https://raw.githubusercontent.com/jdutant/collection/main/collection.lua).)
Save it somewhere in your system, e.g. in your collection's top
folder.

If you save it in a subfolder `filters` of Pandoc's user data
directory, you won't need to provide its path in your Pandoc
commands. See [Pandoc's manual]
(https://pandoc.org/MANUAL.html#option--data-dir) for more on user
data directories in Pandoc. 

# Basic usage

## Commands

Build collections by applying the filter to a master file, e.g.:

```bash
pandoc -L collection.lua master.md -o book.pdf
```

This turns the collection described in `master.md` into `book.pdf`.
(The `-L` flag is an alias for `--lua-filter` and `-o` for
`--output`.) If you're new to Pandoc: by and large the order of
arguments don't matter, so the following works just as well: 

```bash
pandoc --lua-filter collection.lua --output book.pdf master.md
```

The above will only work if `master.md` is located in the folder where
you run the command, and if Pandoc can find `collection.lua`. With
this command Pandoc will find `collection.lua` if it's in the same
folder, or in a `filters` subfolder of your [user data directory]
(https://pandoc.org/MANUAL.html#option--data-dir)). Otherwise you
need to specify paths:

```bash
pandoc -L path/to/collection.lua path/to/master.md -o output.pdf
output.pdf 
```

Replacing `path/to/` with suitable paths (if relative, from the
directory in which you're executing these commands) for the
`collection.lua` and `master.md` files, respectively. For instance,
if your terminal is located at a folder with two subfolders,
`mycollection` containing the master file `master.md` and `resources`
containing the Collection file `collection.lua`, and your want to
output a file `book.html` in the present folder, you should run: 

```bash
pandoc -L resources/collection.lua mycollection/master.md -o book.html
```

You can use any other Pandoc option to control your collection output.
For instance, you'll typically want a standalone document, with the
`--standalone` or `-s` option:

```bash
pandoc -L collection.lua -s -o book.pdf master.md
```

A good practice is to place your options in a [Pandoc *defaults* file]
(https://pandoc.org/MANUAL.html#default-files). For intsance, saving
the following a `book.yaml` next to `master.md`:

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

This will apply the defaults specified to `master.md`: standalone
mode, use the LuaLaTeX pdf engine when producing PDFs, and apply the
`collection.lua` filter. 

## Master files

A master file is a markdown file with a [metadata block in `yaml`
format]
(https://pandoc.org/MANUAL.html#extension-yaml_metadata_block). See
[below](#yaml-primer) for a brief tutorial on the YAML format. The
only metadata field required is a `imports` field specifying a list
of sources:

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

The metadata block in `YAML` format is between `---` and `---`. The
`imports` field specifies source files, to be included in the order
listed. Any text in the document's body will appear before the
imported sources. The source files are listed in that field, each
item in a line starting with a hyphen `- ` (aligned below `imports`,
or indented if you wish).

If sources files are located in other folders, specify their path
relative to the master file (or an absolute path). For instance, if
the folder containing `master.md` has subfolders for each source, the
master file may look like this:

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

By default source files are run through Pandoc before import. This
means that footnotes won't clash: if each `chapter1.md` and
`chapter2.md` have a footnote named `[^1]` or `[^idea]` the links
will still be correct. Internal links across chapters are still
possible, e.g. `as we saw [here](#importantpoint)` in `chapter2.md`
can link to `[Point 1]{#importantpoint}` in `chapter1.md`. For more
details and options, see [below on the building process]
(#the-building-process).

The filter also makes use of these metadata fields (and their aliases)
if present. (If you're not familiar with the term "map", see the
[YAML primer](#yaml-primer) below.)

* `collection`: a map of options to build the collection and
  offprints.
* `offprints`: a map of options to build offprints. Overrides 
  those in `collection` for offprint outputs.
* `child-metadata` (alias `metadata`): metadata passed to the sources
  before import. If building a collection of collections, this is
  only passed to the immediate sources of the collection, not the
  sources of the sources. 
* `global-metadata` (alias `global`): metadata passed to the sources
  in a `global-metadata` field. When building recursively
  (collections of collections ... of collections of sources), this
  trickles down to the sources of the sources. 
* `offprint-mode`. Switch to offprint mode. Normally used on the command
  line.
* ... and other fields of the form `collection-...` that provide
      aliases for collection options, meant to be used on the command
      line. 

A full [list of master fields](#master-file-options) is provided
below.

Here is an example of master file using the `collection` field to
specify options: 

```yaml
---
title: My Journey
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

Here two collection options are specified: `defaults` and `mode`. Note
the indentation needed to indicate that they are sub-fields of
`collection`. (The former specifies a Pandoc defaults file to process
the sources before import, the second specifies the `raw` import mode
in which sources are converted to output before being imported in the
main document. 

Options can also be specified on a per-source basis. For instance, you 
can specify different defaults and import modes for different sources. 
Instead of specifying a file only, you specify a map of options with a
`file` key:

```yaml
---
title: Journal of Serious Studies
imports:
- file: preface.md
  mode: native
  defaults: preface.yaml
- file: article1.md
  mode: raw
  defaults: special-article.yaml
- article2.md
---
```

Here the `article2.md` source is specfied by just giving its file name, 
but `preface.md` and `article1.md` are given with specific options.

# YAML primer

The filter heavily uses (a simple subset of) [YAML syntax]
(https://yaml.org/spec/1.2/spec.html). That is the syntax of metadata
blocks in Pandoc's markdown and of Pandoc's default files. Here is a
primer.

A YAML *map* or *dictionary* is a series of `key:value` pairs. Each
start on a new line. Keys are labels. Simple values can be strings,
numbers or boolean (`true` or `false`):

```yaml
age: 12
hobby: knitting
registered: true
tag-phrase: go steady, go far
```

The metadata block in Pandoc markdown is a map, for instance.

A YAML *list* is a list of `- value` items. Each starts on a new line
with a hyphen. Again, simple values can be strings, numbers,
booleans:

```yaml
- sax
- alto sax
- 1
- true
```

But values need not be simple. They can themselves be maps or lists.
Here is a list of three maps:

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

Note the indentation: each line of the first map starts at the same
point. The following wouldn't be processed correctly:

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

The list items must start at the line below the key, and be at least
as indented as the key. The following would work well too:

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

Here `- Jane Doe` is left of `authors:`, so isn't processed as its
value. 

Here is a map with two keys, `plant` and `animal`. The value of
`plant` is itself a map with three keys and the third key's value is
a list. The value of `animal` is a map with two keys
(`features`, `habitat`) whose values are themselves maps:

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

That's basically all you need for using this filter: understand  maps,
lists, and how to use indentation to use them as values of other maps
and lists. 

While we're at it, a couple of further features useful in Pandoc's
markdown. If a string value contains a colon, put it in single or
double quotes. If it contains single quotes, put it in double quotes
or vice versa. If it contains both, escape them with `\`.

```
title: "My book: a journey"
author: 'John "Big J" Johnson'
editor: Jane Doe
publisher: The \"Hip \'Press
```

The last kind of value besides maps, lists, strings, numbers and
booleans are *text blocks*. These are entered by placing `|` where
the value would have been, and entering the block in the lines below,
each line starting with at least two spaces of indentation. Here is a
map with one key whose value is a block of text:

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

## Structure

Collection builds output following these steps. For each source file:

1. (optional) Prepare the source's metadata. Any metadata that must be 
  passed from the main source is placed in a temporary [metadata file]
  (https://pandoc.org/MANUAL.html#option--metadata-file) used in (2).
2. (optional) Run Pandoc on the source file, applying metadata from (1) 
  and the user's desired settings for that file (defaults, filters, 
  and in `raw` mode, templates).
3. Import the result of (1)-(2) in the main document. If steps (1)-(2)
  are skipped (`direct` mode), the source file is simply read into the 
  main file as in Pandoc's own collection mechanism.    

Once that is done Collection lets Pandoc convert the resulting document 
in output. 

## Import modes

There are three import modes. They can be specified at the collection 
level or for each individual source. To understand their respective 
advantages you need to know the difference between Pandoc *filters* and
*templates*.

* [*Pandoc templates*](https://pandoc.org/MANUAL.html#templates) are 
  templates to produce *output code* (e.g. `html` or `LaTeX`) based on 
  the document's metadata. The output code in question can only be placed
  *around* (before and after) the body of your document: the body's
  conversion is exclusively controlled by Pandoc and placed in a `$body$`
  template variable. For instance, if you want `html` output to include a
  "Author: ..." paragraph before the document's body and a  
  "Date: ..." paragraph at the end, provided your document's metadata
  includes `author` and `date` fields respectively, you'd use the 
  following template (saved as a file `mytemplate.html`):

  ```html
  $if(author)$<p>Author: $author$</p>$endif$
  $body$
  $if(date)$<p>Date: $date$</p>$endif$
  ```

  Pandoc's [template syntax](https://pandoc.org/MANUAL.html#templates)
  is simple and allows for some flexible templating with 
  conditionals, for loops and sub-templates. But it can do more advanced
  operations like search/replace or move and can't alter the document's 
  body. 
* [*Pandoc filters*](https://pandoc.org/MANUAL.html#templates) are 
  small programs that *manipulate Pandoc's internal format*. They are 
  written in a programming language such as Lua or Python. They can do 
  pretty much anything, including producing output code (inserted in
  Pandoc's internal document as `RawBlocks` or `RawInline`) and
  modifying the document's body. To write them, you need to understand
  the language in question and Pandoc's [internal document structure]
  (https://pandoc.org/lua-filters.html#lua-type-reference). If you have
  the choice, it's best to write [Lua filters](https://pandoc.org/lua-filters.html): Pandoc processes them internally (faster, no platform-
  specific dependencies) and the Lua language is relatively easy to
  learn. There are also [plenty of examples](https://github.com/pandoc/lua-filters) to learn from. 

The three import modes are as follows:

* `direct`. Import the source directly in Pandoc's internal format. No
  transformation (defaults, filters, templates) is applied before 
  import. You can decide whether to merge the source metadata into that
  of the main document. This is essentially like Pandoc's own
  collection-building mechanism. Best for simple sources and speed. 
* `native`. Run Pandoc on the source with desired settings and import
  it in Pandoc's internal format. This means 
  that its content will still be structured as paragraphs, headings, 
  emphasis, code blocks, etc. in the main document. If using Pandoc's 
  bibliography engine Citeproc on the source, the formatted bibliography
  will be included too. This is best when you want to apply Pandoc filters
  to the combined document and these filters manipulate structured 
  elements of the document. Downside: you can't use 
  Pandoc templates to format sources before import; only a master-level template can be applied. Any pre-import manipulation must be done 
  with Pandoc defaults and filters instead. 
* `raw`. Run Pandoc on the source with desired settings and import it
  in the target output format. Its content converted to output code
  (or a suitable intermediate format, e.g. LaTeX if the final format
  is PDF) and inserted in the combined document as a
  [RawBlock element]
  (https://pandoc.org/lua-filters.html#type-rawblock). This is best
  when you want to use Pandoc templates to format each source
  separately. Downside: because the imported parts are already in output
  format, filters applied to the combined document will not 'see' the 
  inner structure of these parts (they won't easily identify headers,
  paragraphs, quotation blocks etc). 

As a rule of thumb, `direct` is good for the simplest sources, `native` 
when sources are part of a whole (e.g. chapters or sections) and `raw`
when sources are independent (e.g. different articles in a collection).

## Offprint mode

In offprint mode only one source is imported. This is activated by
setting the metadata variable `offprint-mode` to the number of that
source in the list. For instance, a master file with this metadata
will only produce chapter 3:

```yaml
offprint-mode: 3
imports:
- chapter_1.md 
- chapter_2.md 
- chapter_3.md 
```

The option is most naturally used at the command line rather than
in the master file metadata. Use Pandoc's [command line option `-M` alias
`--metadata`](https://pandoc.org/MANUAL.html#option--metadata):

```bash
pandoc -L collection.lua master.md -M offprint-mode=3 -o chap3.pdf
pandoc -L collection.lua master.md --metadata=offprint-mode:3 -o chap3.pdf
```

Note that in offprint mode `gather` will only gather metadata from the 
source that is offprinted, not from the other sources.

If you want to use alternative defaults files or `gather/pass/globalize` 
options for offprints, use the `offprints` metadata key:

```yaml
collection:
  defaults: chapter-in-collection.yaml
offprints:
  defaults: chapter-offprint.yaml
imports:
- chapter_1.md 
- chapter_2.md 
- chapter_3.md 
```

# Master file options

Overall structure:

```yaml
metadata: # alias `child-metadata`
global: # alias `global-metadata`
collection:
  gather:
  replace:
  globalize:
  pass:
  defaults:
offprints:
  gather: 
  replace:
  globalize:
  pass:
  defaults:
imports:
- file: 
  defaults:
  metadata: # alias of child-metadata

```

Description of each key. We write `key/subkey` to indicate that `subkey`
is a key within a map (or list of maps) in `key`.

`metadata` alias `child-metadata`
: map of YAML metadata passed to sources before import

`global` alias `global-metadata`
: map of YAML metadata passed to sources under the key `global` before import

`collection`
: map of collection options, or string giving the filepath of a defaults
file to be used when importing sources (see `collection/defaults`). 

`offprints`
: like `collection`, but used when producing offprints. If not provided, 
the `collection` key is used. If provided, this wholly replaces the
`collection` value when producing offprints. Make sure you duplicate 
any `collection` options desired when producing offprints too.

`imports`
: list of sources. Each item can be a string, the filepath of the 
  source to import, or a map of options describing the source: `file`,
  `metadata`, `defaults`, .... If there is only one source, `imports`
  can simply be its filepath or its map of options. Examples:

  ```yaml
  imports: body.md
  ```

`collection/gather`
: list of metadata keys gathered from sources before import. If the same 
key is present in several documents, it will be turned into a list. This 
behaviour is useful for `header-includes` and `bibliography`. Example:
`gather: [bibliography, header-includes]`.

`collection/gather`
: list of metadata keys replaced by those from sources. If the key is 
already present in the main document, its value is replaced with the 
value it has (if any) in the source. If the source doesn't have that
key, nothing is changed. Useful in offprint mode, to get the value of
the key in that source (e.g. author, starting page, etc.). In 
collection mode, the latest value found (e.g., that of the last source)
prevails. 

`collection/pass`
: metadata keys passed to sources before import. Example: 
`pass: [volume,issue]`

`collection/defaults`
: default file (with path from working directory) to be used on importing
sources.

`offprints/gather`
: like `collection/gather`, but only used when generating offprints.

`offprints/globalize`
: like `collection/globalize`, but only used when generating offprints.

`offprints/pass`
: like `collection/pass`, but only used when generating offprints.

`import/file`
: the filepath of a source.

`import/defaults`
: the defaults file filepath to be used when importing the source.

`import/metadata` alias `import/child-metadata`
: metadata map to be passed to the source before import. Example:

  ```yaml
  imports: 
  - file: preface.md
    metadata: 
      author: Jim Doe
      date: 20 june 2021
  - file: chapter-02.md
    metadata: 
      author: Jane Doe
      date: 22 june 2021
  ```



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

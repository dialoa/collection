---
title: My collection
collection:
    defaults: resources/chapter.yaml
imports:
- chapter1.md
- chapter2/master.md
---

# Introduction

This document demonstrates how to use the `collection` filter
recursively. Each chapter is imported with the settings specified in
the `defaults` file; these settings require `collection` to be ran on
the chapters themselves. This allows us to have a chapter 2 that is
itself a collection. 
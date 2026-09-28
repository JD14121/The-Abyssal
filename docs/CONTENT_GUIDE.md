# Content Guide

## Purpose

This document defines how new gameplay content should be added.

## General Rule

Do not implement a new ordinary content entry by creating a new gameplay script.

Prefer:

JSON data
+
existing gameplay systems

## Naming

Use lowercase snake_case IDs.

Example:

canned_beans
kitchen_knife
bandage_clean

## Content Workflow

The current material/item pipeline supports the first validation and loading
steps below. Balance review and playtesting are future gameplay work:

Design
-> JSON Entry
-> Schema Validation
-> ID Validation
-> Reference Validation
-> Game Load
-> Automated Tests
-> Balance Review
-> Playtest

## Items

Items should be grouped by content purpose.

Examples:

data/items/food/
data/items/medicine/
data/items/weapons/
data/items/tools/
data/items/clothing/
data/items/misc/

## Data Ownership

JSON describes what an object is.

GDScript describes how game systems behave.

Avoid embedding complex executable behavior in content data.

## Current Material and Item Workflow

Add JSON objects or arrays under `game/data/materials/` or `game/data/items/`.
Subdirectories are supported. Follow the required fields and defaults in
[DATA_SCHEMA.md](DATA_SCHEMA.md), then run the four Python tools documented in
[README.md](../README.md). Start the Godot data verification scene to confirm the
runtime path as well. Unknown fields warn; invalid fields, IDs and references fail
the whole load. Keep intentionally invalid examples in test fixtures.

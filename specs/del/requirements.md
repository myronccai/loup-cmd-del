# Requirements: del

## Introduction

`del` (also `erase`) is the cmd.exe built-in that deletes files. This
repository recreates it in Loup for Linux, keeping Windows' operand syntax
(`\` separators, `*` and `?` expanded by the command), its questions,
messages and ERRORLEVELs. It uses the shared Windows code in `source/win/`
(copied from loup-cmd-type).

## Requirements

### Requirement 1: Deleting

**User Story:** As a cmd user, I want to delete files by name, pattern or
directory.

#### Acceptance Criteria

1. WHEN an operand is a file, THE program SHALL delete it and print nothing.
2. WHEN the last component has `*` or `?`, THE program SHALL delete every
   matching file (Windows rules, any case); a plain name SHALL match
   exactly.
3. WHEN an operand is a directory, THE program SHALL delete every file in
   it (not the directory, not subdirectories without `/S`).
4. WITH `/S`, THE program SHALL also delete the matching files in every
   subdirectory, in `/S` order, printing `Deleted file - PATH` for each.
5. THE program SHALL never delete a directory.
6. THE program SHALL handle several operands in order.

### Requirement 2: Questions

**User Story:** As a cmd user, I want to be asked before a whole directory
is emptied, and on request before each file.

#### Acceptance Criteria

1. WHEN an operand is a directory, `*` or `*.*`, THE program SHALL ask
   `PATH, Are you sure (Y/N)? ` and go on only on Y; `/Q` SHALL skip it.
2. WITH `/P`, THE program SHALL ask `PATH, Delete (Y/N)? ` for each file
   instead.
3. THE program SHALL read each answer as one line of standard input
   (Y or N in any case; anything else asks again; the end of input is N),
   and echo it when standard input is not a terminal.

### Requirement 3: Read-only files and attributes

**User Story:** As a cmd user, I want read-only files protected unless I
force it.

#### Acceptance Criteria

1. WHEN a file is read-only (not writable for the user), THE program SHALL
   print its path and `Access is denied.` and keep it, unless `/F` is
   given.
2. `/A[[:]attrs]` SHALL keep only files with the given attributes: `R`
   read-only, `-R` not; `H S A I L O` SHALL be accepted, and no file has
   them.

### Requirement 4: Messages and status

**User Story:** As a script author, I want Windows' messages and
ERRORLEVELs.

#### Acceptance Criteria

1. WHEN nothing matches an operand, THE program SHALL print
   `Could Not Find PATH` (the operand's absolute path with `\`).
2. WHEN the operand's directory does not exist, THE program SHALL print
   `The system cannot find the path specified.`; WHEN a wildcard appears in
   a directory component, `The filename, directory name, or volume label
   syntax is incorrect.`
3. WHEN no operand is given, THE program SHALL print `The syntax of the
   command is incorrect.` and exit 1; WHEN an `/A` value is not valid,
   `Parameter format not correct - "VALUE".` and exit 1.
4. OTHERWISE THE program SHALL exit 0, also when files were missing or
   refused, as cmd does.
5. `/?` SHALL print a short help text and exit 0; `--help` and `--version`
   alone SHALL print the help and `del (loup-cmd-del) 0.1.0`. A `/X` that is
   not one of del's switches SHALL be an operand.

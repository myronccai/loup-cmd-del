# Design: del

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser, handles `/?` and `--version`, and calls
`commands.erase.run_del` (the module is `erase` because `del` is a Loup
reserved word). `run_del` plans each operand (`plan_target`), finds its
files (`find_files`), filters them by `/A`, asks if needed, deletes and
prints.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `Options`, `del_switches()`, `valid_attrs`, `parse_args` |
| `source/cli/usage.loup` | `usage()` (a short help text), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/erase.loup` | `Target`, `plan_target`, `find_files`, `attrs_match`, `is_read_only`, `delete_file`, `run_del` |
| `source/commands/prompt.loup` | `read_line`, `stdin_is_terminal`, `parse_answer`, the two questions, `ask_yes_no` |
| `source/commands/cwd.loup` | `normalize_absolute`, `absolute_path`, `current_dir` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

`plan_target` turns an operand into (directory, pattern, everything,
error): an existing directory is (dir, `*`, everything); otherwise the
operand is split at its last separator and the directory must exist.
`find_files` lists the pattern in the directory, or with `/S` in every
directory from `win.wildcard.walk_dirs`; patterns use `list_matches`
(files only, any case), plain names an exact `isFile`.

Read-only is "not writable": `is_read_only` runs `test -w` (Loup 1.26.0
has no `stat()` or `access()`); it is only called without `/F` or for an
`/A` value with `R`. `delete_file` calls `io.fs.remove` (unlink: a symbolic
link goes, its target stays) and checks the disk afterwards, since native
builds fail silently and Stage0 throws.

Questions read one line of standard input through a `sh` child
(`IFS= read -r line`), which inherits standard input and consumes exactly
one line, so answers can come from the terminal or a pipe.

## Differences from the original

- `erase` is a symlink to `del`.
- Read-only means not writable for the user (`test -w`); root sees nothing
  read-only.
- No hidden, system or archive attributes.
- Answers need Enter; non-terminal answers are echoed.
- Paths have no drive letter; plain names are case-sensitive.
- `/?` prints this recreation's own short help text.

## Error handling

Every operand is handled on its own: errors are printed and the next
operand follows. Only usage errors give status 1. An unexpected exception
is printed on standard error and gives status 1.

## Testing

- `tests/args_test.loup`: switches, `/A` values, paths that look like
  switches, help and version.
- `tests/erase_test.loup`: `plan_target`, `find_files` (patterns, exact
  names, `/S` order, directories), `attrs_match`, `delete_file`, messages.
- `tests/prompt_test.loup`, `tests/cwd_test.loup`: answers, questions,
  absolute paths.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary (and `erase`); every case starts from a
  fresh tree under `$TMP` (with a read-only file) and checks the tree
  afterwards; answers come from files on standard input.

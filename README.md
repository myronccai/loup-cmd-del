# loup-cmd-del

The Windows `del` (and `erase`) command recreated in
[Loup](https://code-craft.ai/references/loup): delete files, with cmd's
wildcards, `\` paths, questions, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                     # native binary build/del, and build/erase (a symlink to it)
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="/Q build/tmp/x.txt"   # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/del 'demo\*.tmp'
$ build/del 'demo\missing.txt'; echo "ERRORLEVEL $?"
Could Not Find \home\myron\repos\ccai-examples\loup-cmd-del\build\demo\missing.txt
ERRORLEVEL 0
$ build/del /S 'demo\app.log'
Deleted file - \home\myron\repos\ccai-examples\loup-cmd-del\build\demo\logs\app.log
Deleted file - \home\myron\repos\ccai-examples\loup-cmd-del\build\demo\logs\old\app.log
$ build/del 'demo\tmp'
\home\myron\repos\ccai-examples\loup-cmd-del\build\demo\tmp\*, Are you sure (Y/N)? y
$ build/del 'demo\locked.txt'
\home\myron\repos\ccai-examples\loup-cmd-del\build\demo\locked.txt
Access is denied.
$ build/del /F 'demo\locked.txt'
$ build/erase /P 'demo\*.txt'
\home\myron\repos\ccai-examples\loup-cmd-del\build\demo\notes.txt, Delete (Y/N)? n
$ build/del
The syntax of the command is incorrect.
```

`del [/P] [/F] [/S] [/Q] [/A[[:]attrs]] name...`

- A name is a file, a pattern with `*` and `?` in its last component
  (Windows rules, any case), or a directory, which means every file in it.
  Directories themselves are never deleted.
- `/S` also deletes the matching files in every subdirectory, and prints
  `Deleted file - PATH` for each.
- A directory, `*` or `*.*` first asks `PATH, Are you sure (Y/N)?`; `/Q`
  skips the question.
- `/P` asks `PATH, Delete (Y/N)?` for each file instead.
- A read-only file (no write permission) is refused with `Access is
  denied.` unless `/F` is given.
- `/A[attrs]` keeps only files with the attributes: `R` read-only, `-R`
  writable; `H S A I L O` are accepted and no file has them.
- Answers are read one line at a time from standard input (`y` or `n`, in
  any case; anything else asks again; the end of input means no).
- Switches start with `/` or `-` in any case; a `/X` that is not one of
  del's switches is a path, and `--` ends switch parsing. `/?` prints a
  short help; `--help` and `--version` work as the only argument.

Exit status (ERRORLEVEL): `1` only for usage errors (no name, a bad `/A`
value). As in cmd, files that are missing (`Could Not Find ...`) or cannot
be deleted (`Access is denied.`) are reported and the status stays `0`.

## Differences from the original

- `erase` is a symlink to the same binary (`build/erase`); both print
  `del` in `--version`.
- Read-only means "no write permission for this user" (checked with
  `test -w`, since Loup 1.26.0 has no `stat()`); on Linux such a file could
  be unlinked anyway, del refuses it as Windows does. Run as root, nothing
  is read-only.
- No hidden, system or archive attributes: dot-files are ordinary files,
  and `/AH`, `/AS`, `/AA` find nothing.
- Answers are whole lines (Enter needed); cmd reacts to the key press. When
  standard input is not a terminal, the answer is echoed after the
  question.
- Paths are printed from `$PWD` (or `pwd`), without a drive letter.
- A plain name must match exactly (Linux names are case-sensitive);
  patterns ignore case. No 8.3 short names, so `*.txt` does not match
  `a.txtx`.
- A file that cannot be removed for another reason (its directory is
  read-only) is also reported as `Access is denied.`
- `/?` prints a short help text of this recreation, not Windows' own.
  Messages end with LF, not CRLF.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # /P /F /S /Q /A via win.switches
source/cli/usage.loup          # /? and --version text
source/cli/app.loup            # run(): parse, dispatch, exit status
source/commands/erase.loup     # plan_target(), find_files(), delete_file(), run_del() (`del` is a Loup reserved word)
source/commands/prompt.loup    # the Y/N questions, one line of stdin at a time
source/commands/cwd.loup       # absolute paths for messages ($PWD or pwd)
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/del (make e2e)
specs/del/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

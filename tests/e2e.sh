#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. Every case runs in a fresh fixture tree under $TMP, and
# the tree is checked afterwards: del only ever touches paths under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree, rebuilt before every case. ro.txt is read-only.
W="$TMP/w"
reset() {
    cd "$TMP" && rm -rf "$W"
    mkdir -p "$W/sub/deep" "$W/empty"
    printf 'a\n' > "$W/a.txt"
    printf 'b\n' > "$W/b.txt"
    printf 'C\n' > "$W/C.TXT"
    printf 'log\n' > "$W/c.log"
    printf 'ro\n' > "$W/ro.txt"; chmod a-w "$W/ro.txt"
    printf 'sa\n' > "$W/sub/a.txt"
    printf 'sx\n' > "$W/sub/x.log"
    printf 'da\n' > "$W/sub/deep/a.txt"
    cd "$W"
}

# The tree as one line per entry: `dir/` or `file=content`.
state() {
    (cd "$W" && find . -mindepth 1 | LC_ALL=C sort | while read -r p; do
        if [ -d "$p" ]; then echo "${p#./}/"; else echo "${p#./}=$(cat "$p")"; fi
    done)
}

# check_state NAME EXPECTED: the tree after the last case.
check_state() {
    local got
    got=$(state)
    if [ "$got" = "$2" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1 (tree)"
        diff <(echo "$2") <(echo "$got") | sed 's/^/    /'
    fi
}

# without NAME...: the starting tree minus the named entries.
START=$'C.TXT=C\na.txt=a\nb.txt=b\nc.log=log\nempty/\nro.txt=ro\nsub/\nsub/a.txt=sa\nsub/deep/\nsub/deep/a.txt=da\nsub/x.log=sx'
without() {
    local out="$START" name
    for name in "$@"; do
        out=$(echo "$out" | grep -v -x -F "$name")
    done
    echo "$out"
}

WD=${W//\//\\}
printf 'y\n' > "$TMP/yes"; printf 'n\n' > "$TMP/no"; printf 'what\ny\n' > "$TMP/retry"
printf 'y\nn\ny\n' > "$TMP/yny"

# Help and version; erase is the same program.
reset
"$BIN" '/?' > "$TMP/help" 2>&1
if [ "$(head -1 "$TMP/help")" = 'Delete files.' ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: /? help"; fi
check      "--version"          0 $'del (loup-cmd-del) 0.1.0\n' --version

# Plain deletes print nothing.
reset; check_both "one file"    0 '' ''                         a.txt
check_state "one file" "$(without a.txt=a)"
reset; check_both "several operands" 0 '' ''                    a.txt 'sub\x.log' "$W/b.txt"
check_state "several operands" "$(without a.txt=a sub/x.log=sx b.txt=b)"
reset; check_both "pattern, any case" 0 '' "$WD\\ro.txt"$'\nAccess is denied.\n' '*.TXT'
check_state "pattern, any case" "$(without a.txt=a b.txt=b C.TXT=C)"
reset; check_both "plain names are exact" 0 '' "Could Not Find $WD\\A.TXT"$'\n' A.TXT
check_state "plain names are exact" "$START"
reset; check_both "question mark" 0 '' ''                       '?.log'
check_state "question mark" "$(without c.log=log)"

# Not found: a message, and ERRORLEVEL stays 0 (as in cmd).
reset; check_both "missing file" 0 '' "Could Not Find $WD\\nope.txt"$'\n' nope.txt
reset; check_both "no match"    0 '' "Could Not Find $WD\\sub\\*.none"$'\n' 'sub\*.none'
reset; check_both "empty directory" 0 '' "Could Not Find $WD\\empty\\*"$'\n' /Q empty
reset; check_both "missing directory" 0 '' $'The system cannot find the path specified.\n' 'nodir\a.txt'
reset; check_both "wildcard in directory" 0 '' \
    $'The filename, directory name, or volume label syntax is incorrect.\n' 's*\a.txt'
reset; check_both "found and missing" 0 '' "Could Not Find $WD\\nope.txt"$'\n' nope.txt a.txt
check_state "found and missing" "$(without a.txt=a)"

# /S deletes in every subdirectory and names each file.
reset; check_both "/S"          0 "Deleted file - $WD\\a.txt
Deleted file - $WD\\sub\\a.txt
Deleted file - $WD\\sub\\deep\\a.txt
" ''                                                            /S a.txt
check_state "/S" "$(without a.txt=a sub/a.txt=sa sub/deep/a.txt=da)"
reset; check "/S pattern in a subdirectory" 0 "Deleted file - $WD\\sub\\x.log
"                                                               /s 'sub\*.log'
reset; check_both "/S no match" 0 '' "Could Not Find $WD\\*.none"$'\n' /S '*.none'

# Everything in a directory (`*`, `*.*`, a directory operand) asks first;
# the answer is a line of stdin. ro.txt is refused (read-only).
sure="$WD\\*, Are you sure (Y/N)? "
denied="$WD\\ro.txt"$'\nAccess is denied.\n'
reset; IN="$TMP/yes" check_both "star, yes" 0 "${sure}y
" "$denied"                                                     '*'
check_state "star, yes" $'empty/\nro.txt=ro\nsub/\nsub/a.txt=sa\nsub/deep/\nsub/deep/a.txt=da\nsub/x.log=sx'
reset; IN="$TMP/no" check_both "star, no" 0 "${sure}n
" ''                                                            '*'
check_state "star, no" "$START"
reset; IN="$TMP/retry" check "asks again" 0 "${sure}what
${sure}y
"                                                               '*'
reset; check "end of input is no" 0 "${sure}
"                                                               '*'
check_state "end of input is no" "$START"
reset; IN="$TMP/no" check "star dot star asks" 0 "$WD\\*.*, Are you sure (Y/N)? n
"                                                               '*.*'
reset; check_both "/Q does not ask" 0 '' "$denied"              /Q '*'
check_state "/Q does not ask" $'empty/\nro.txt=ro\nsub/\nsub/a.txt=sa\nsub/deep/\nsub/deep/a.txt=da\nsub/x.log=sx'
reset; IN="$TMP/yes" check "a directory means its files" 0 "$WD\\sub\\*, Are you sure (Y/N)? y
"                                                               'sub\'
check_state "a directory means its files" $'C.TXT=C\na.txt=a\nb.txt=b\nc.log=log\nempty/\nro.txt=ro\nsub/\nsub/deep/\nsub/deep/a.txt=da'
reset; check "/S /Q on a directory" 0 "Deleted file - $WD\\sub\\a.txt
Deleted file - $WD\\sub\\x.log
Deleted file - $WD\\sub\\deep\\a.txt
"                                                               /S /Q sub
check_state "/S /Q on a directory" $'C.TXT=C\na.txt=a\nb.txt=b\nc.log=log\nempty/\nro.txt=ro\nsub/\nsub/deep/'

# /P asks for each file.
reset; IN="$TMP/yny" check "/P" 0 "$WD\\a.txt, Delete (Y/N)? y
$WD\\b.txt, Delete (Y/N)? n
$WD\\C.TXT, Delete (Y/N)? y
$WD\\ro.txt, Delete (Y/N)? 
"                                                               /P '*.txt'
check_state "/P" "$(without a.txt=a C.TXT=C)"

# Read-only files need /F; /A filters by attribute.
if [ "$(id -u)" != 0 ]; then
    reset; check_both "read-only" 0 '' "$denied"                ro.txt
    check_state "read-only" "$START"
    reset; check_both "/F"      0 '' ''                         /F ro.txt
    check_state "/F" "$(without ro.txt=ro)"
    reset; check_both "/A:R"    0 '' ''                         /Q /F /A:R '*'
    check_state "/A:R" "$(without ro.txt=ro)"
    reset; check_both "/A-R"    0 '' ''                         /A-R '*.txt'
    check_state "/A-R" "$(without a.txt=a b.txt=b C.TXT=C)"
fi
reset; check_both "/AH finds nothing" 0 '' "Could Not Find $WD\\*.txt"$'\n' /AH '*.txt'

# erase is del.
reset; BIN_DEL=$BIN; BIN=$(dirname "$BIN")/erase
check_both "erase"              0 '' ''                         b.txt
BIN=$BIN_DEL
check_state "erase" "$(without b.txt=b)"

# Usage errors are the only ERRORLEVEL 1.
reset; check_both "no operand"  1 '' $'The syntax of the command is incorrect.\n'
check_both "bad attribute"      1 '' $'Parameter format not correct - "D".\n' /A:D a.txt
check_both "unknown switch is a path" 0 '' "Could Not Find $WD\\-z"$'\n' -z
check_state "usage errors change nothing" "$START"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

# shellcheck shell=sh
# EDBP Bash history policy: retain history only in the current shell process.
if [ -n "${BASH_VERSION:-}" ]; then
    if [ "${HISTFILE-}" != /dev/null ]; then
        HISTFILE=/dev/null
    fi
    HISTSIZE=1000
    export HISTFILE
    readonly HISTFILE
fi

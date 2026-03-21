#!/usr/bin/env bash
#
# Timothy C. Arland <tarland@trace3.com>
#
env_secrets_setup="v26.03.20"
pname=${0##*\/}
dryrun=0
action=
envname=
repopath=

subpaths=("auth" "certs" "configs" "files")

rsync_args=(
    "-avc"
    "--no-perms"
    "--no-owner"
    "--no-group"
    "--no-times"
    "--delete"
)

usage="
Synchronizes the environment configuration for a given
project, managing the secrets and ensuring that the various 
configuration secrets are properly encrypted when committed. 
This tool uses 'ansible-vault' to perform the encryption.

Synopsis:
  env-secrets-setup.sh [options] <action> [envname]

Options:
  -h|--help        : Show usage info and exit.
  -n|--dryrun      : Enable 'dryrun' on encrypt|sync actions.
  -V|--version     : Show version info and exit.
  -R|--repo <path> : Path to parent repo to overlay.

Actions:
  'encrypt'        : Encrypt an environment or all ENVs as needed.
  'decrypt'        : Decrypt files for a given environment.
  'restore'        : Restores previous encryption state.
  'sync'           : Synchronize files for a given environment.

  [envname]        : The environment name on which to operate.
"

# --------------------------------------------------------------

function isEncrypted()
{
    local file="$1"
    if head -1 $file | grep "ANSIBLE_VAULT" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}


function encrypt()
{
    local name="$1"
    local cnt=0

    if ! isEncrypted "env/${name}/${name}.env"; then
        cnt=$(($cnt + 1))
        if [ $dryrun -eq 0 ]; then
            echo "-> Encrypting ${name}.env"
            ansible-vault encrypt "env/${name}/${name}.env" >/dev/null
            if [ $? -ne 0 ]; then
                return 0
            fi
        fi
    fi

    for p in ${subpaths[@]}; do
        if [ ! -d env/${name}/$p ]; then
            continue
        fi
        echo "-> Encrypting files in 'env/$name/$p'"
        for f in $(ls -1 env/${name}/$p/* 2>/dev/null); do
            if ! isEncrypted "$f"; then
                cnt=$(($cnt + 1))
                if [ $dryrun -eq 0 ]; then
                    echo "  -> Encrypting $f"
                    ansible-vault encrypt "$f" >/dev/null
                fi
            fi
        done
    done

    return $cnt
}


function decrypt
{
    local name="$1"

    if isEncrypted "env/${name}/${name}.env"; then
        echo "-> Decrypting ${name}.env"
        ansible-vault decrypt "env/${name}/${name}.env" >/dev/null
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi

    for p in ${subpaths[@]}; do
        if [ ! -d env/${name}/$p ]; then
            continue
        fi
        echo "-> Decrypting files in env/$name/$p/"
        for f in $(ls -1 env/${name}/$p/* 2>/dev/null); do
            if isEncrypted "$f"; then
                echo "  -> Decrypting $f"
                ansible-vault decrypt "$f" >/dev/null
            fi
        done
    done

    return 0
}

# --------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
    'help'|-h|--help)
        echo "$usage"
        exit 0
        ;;
    -n|--dryrun|--dry-run)
        dryrun=1
        ;;
    -R|--repopath)
        repopath="$2"
        shift
        if [ ! -d $repopath ]; then
            echo "$pname Error, provided repopath '$repopath' not found" >&2
            exit 1
        fi
        ;;
    -V|--version)
        echo "$pname $env_secrets_setup"
        exit 0
        ;;
    *)
        action="$1"
        envname="${2}"
        shift $#
    esac
    shift
done


if ! which ansible-vault >/dev/null 2>&1; then
    echo "$pname Error, 'ansible-vault' binary not found in PATH" >&2
    exit 1
fi

if [ -z "$action" ]; then
    echo "$pname Error, 'action' must be specified." >&2
    echo "  Use '--help' to review usage information" >&2
    exit 1
fi

if [ "$action" != "encrypt" ]; then
    if [[ -z "$envname"  ]]; then
        echo "$pname Error, environment name not provided" >&2
        exit 1
    fi
    if [[ "$envname" == "example" ]]; then
        echo "$pname Error, environment name 'example' is reserved" >&2
        exit 1
    fi
    if [[ ! -d env/${envname} && "$action" ]]; then
        echo "$pname Error, environment not found for '$envname'" >&2
        exit 1
    fi
    if [[ ! -f env/${envname}/${envname}.env ]]; then
        echo "$pname Error, environment file not found for '$envname'" >&2
        exit 1
    fi
fi

# --------------------------------------------------------------

rt=0

case "$action" in
'encrypt'|'encode')
    if [ -n "$envname" ]; then
        encrypt "$envname"
        rt=$?
    else
        for name in env/*; do
            envname="${name##*\/}"
            cnt=0
            if [[ "$envname" == "example" ]]; then
                continue
            fi
            if [[ -d $name && -f $name/$envname.env ]]; then
                encrypt "$envname"
                cnt=$?
                rt=$(($rt + $cnt))
                if [[ $cnt -gt 0 && $dryrun -eq 0 ]]; then
                    echo "-> Encrypted $cnt files for $envname"
                fi
            fi
        done
    fi
    ;;

'decrypt'|'decode')
    decrypt "$envname"
    rt=$?
    ;;

'restore')
    ( git restore "env/${envname}/" )
    ;;

'sync')
    if ! which rsync >/dev/null 2>&1; then
        echo "$pname Error, 'sync' action requires 'rsync' in the PATH." >&2
        exit 1
    fi
    if [[ ! -d ${repopath}/env ]]; then
        echo "$pname Error location '$repopath/env' not found." >&2
        exit 1
    fi

    cur=$(git status -s | grep "${envname}" | wc -l)
    decrypt "$envname"
    if [ $? -ne 0 ]; then
        echo "$pname Error during decrypt of '$envname'" >&2
        exit 1
    fi

    if [ $dryrun -eq 1 ]; then
        rsync_args+=("--dry-run")
    fi

    echo "rsync ${rsync_args[@]} ./env/${envname}/ ${repopath}/env/${envname}/"
    rsync ${rsync_args[@]} ./env/${envname}/ ${repopath}/env/${envname}/
    rt=$?

    if [ $cur -eq 0 ]; then
        ( git restore "env/$envname" )
    else
        echo ""; echo "#### WARNING ####"
        echo "Uncommitted changes detected for env '$envname'"
        echo "Script has not run 'git restore' for the environment"
    fi
    ;;

*)
    echo "$usage"
    ;;
esac

exit $rt

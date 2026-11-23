#!/usr/bin/env bash
# Shared transactional strict-sed support for Alice patch scripts.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    printf 'alice-patch-transaction.sh must be sourced by a patch script\n' >&2
    exit 1
fi

if [[ -n ${ALICE_PATCH_TRANSACTION_LOADED:-} ]]; then
    return 0
fi
ALICE_PATCH_TRANSACTION_LOADED=1
ALICE_PATCH_TRANSACTION_SCRIPT="${BASH_SOURCE[1]##*/}"

declare -a ALICE_PATCH_TXN_ORIGINALS=()
declare -a ALICE_PATCH_TXN_STAGED=()
declare -a ALICE_PATCH_TXN_BACKUPS=()
declare -A ALICE_PATCH_TXN_STAGE_BY_ORIGINAL=()
declare -A ALICE_PATCH_TXN_ORIGINAL_BY_STAGED=()
ALICE_PATCH_TXN_FILE_INDEX=0
ALICE_PATCH_TXN_SED_INDEX=0

_alice_patch_txn_cleanup() {
    local root="${ALICE_PATCH_TXN_ROOT:-}"

    [[ -n "$root" && -d "$root" ]] || return 0
    case "$root" in
        */.alice-patch-transaction.*)
            rm -rf -- "$root"
            ;;
        *)
            printf 'Alice patch transaction: refusing to remove unexpected path: %s\n' \
                    "$root" >&2
            return 1
            ;;
    esac
}

_alice_patch_txn_rollback_commit() {
    local index=$1

    while ((index >= 0)); do
        if [[ -e "${ALICE_PATCH_TXN_BACKUPS[index]}" ]]; then
            if ! mv -f -- "${ALICE_PATCH_TXN_BACKUPS[index]}" \
                    "${ALICE_PATCH_TXN_ORIGINALS[index]}"; then
                printf 'Alice patch transaction: failed to restore %s\n' \
                        "${ALICE_PATCH_TXN_ORIGINALS[index]}" >&2
            fi
        fi
        ((index--))
    done
}

_alice_patch_txn_commit() {
    local index target staged backup cmp_status

    for index in "${!ALICE_PATCH_TXN_ORIGINALS[@]}"; do
        target="${ALICE_PATCH_TXN_ORIGINALS[index]}"
        staged="${ALICE_PATCH_TXN_STAGED[index]}"
        backup="${ALICE_PATCH_TXN_BACKUPS[index]}"

        cmp_status=0
        cmp -s -- "$target" "$staged" || cmp_status=$?
        if ((cmp_status == 0)); then
            continue
        fi
        if ((cmp_status > 1)); then
            printf 'Alice patch transaction: failed to compare staged file: %s\n' \
                    "$target" >&2
            _alice_patch_txn_rollback_commit "$((index - 1))"
            return 1
        fi

        if ! mv -f -- "$target" "$backup"; then
            printf 'Alice patch transaction: failed to stage original: %s\n' \
                    "$target" >&2
            _alice_patch_txn_rollback_commit "$((index - 1))"
            return 1
        fi

        if ! mv -f -- "$staged" "$target"; then
            printf 'Alice patch transaction: failed to install staged file: %s\n' \
                    "$target" >&2
            if ! mv -f -- "$backup" "$target"; then
                printf 'Alice patch transaction: failed to restore current file: %s\n' \
                        "$target" >&2
            fi
            _alice_patch_txn_rollback_commit "$((index - 1))"
            return 1
        fi
    done
}

_alice_patch_txn_exit() {
    local status=$?

    trap - EXIT
    if ((status == 0)); then
        if ! _alice_patch_txn_commit; then
            status=1
        fi
    fi

    if ! _alice_patch_txn_cleanup && ((status == 0)); then
        status=1
    fi
    exit "$status"
}

_alice_patch_txn_stage_path() {
    local name=$1
    local original="${!name}"
    local resolved
    local staged

    if [[ ! -f "$original" ]]; then
        printf 'Alice patch transaction: source is not a file: %s\n' \
                "$original" >&2
        return 1
    fi

    resolved="$(realpath -m -- "$original")" || return 1
    if [[ -n ${ALICE_PATCH_TXN_STAGE_BY_ORIGINAL[$resolved]+x} ]]; then
        staged="${ALICE_PATCH_TXN_STAGE_BY_ORIGINAL[$resolved]}"
    else
        staged="${ALICE_PATCH_TXN_ROOT}/staged/file${ALICE_PATCH_TXN_FILE_INDEX}"
        cp -a -- "$resolved" "$staged" || return 1
        ALICE_PATCH_TXN_ORIGINALS+=("$resolved")
        ALICE_PATCH_TXN_STAGED+=("$staged")
        ALICE_PATCH_TXN_BACKUPS+=(
            "${ALICE_PATCH_TXN_ROOT}/backups/file${ALICE_PATCH_TXN_FILE_INDEX}"
        )
        ALICE_PATCH_TXN_STAGE_BY_ORIGINAL[$resolved]="$staged"
        ALICE_PATCH_TXN_ORIGINAL_BY_STAGED[$staged]="$resolved"
        ((ALICE_PATCH_TXN_FILE_INDEX += 1))
    fi

    printf -v "$name" '%s' "$staged"
}

_alice_patch_txn_begin() {
    local index=1
    local name

    ALICE_PATCH_TXN_ROOT="$(mktemp -d -p "$PWD" .alice-patch-transaction.XXXXXX)" ||
        return 1
    trap _alice_patch_txn_exit EXIT

    mkdir -p -- \
            "${ALICE_PATCH_TXN_ROOT}/staged" \
            "${ALICE_PATCH_TXN_ROOT}/candidates" \
            "${ALICE_PATCH_TXN_ROOT}/backups" || return 1

    while declare -p "path${index}" >/dev/null 2>&1; do
        name="path${index}"
        _alice_patch_txn_stage_path "$name" || return 1
        ((index += 1))
    done

    if ((index == 1)); then
        printf 'Alice patch transaction: no pathN variables were found\n' >&2
        return 1
    fi
}

_alice_patch_txn_remove_candidates() {
    local candidate

    for candidate in "$@"; do
        rm -f -- "$candidate"
    done
}

sed() {
    if [[ ${1-} != "-i" && ${1-} != "--in-place" ]]; then
        command sed "$@"
        return
    fi

    if [[ -z ${ALICE_PATCH_TXN_ROOT:-} ]]; then
        printf 'Alice patch transaction: sed -i was called outside a transaction\n' >&2
        return 1
    fi

    shift
    local -a sed_args=()
    local -a files=()
    local -a candidates=()
    local -a staged_targets=()
    local program_seen=0

    while (($#)); do
        case "$1" in
            -e|--expression|-f|--file)
                (($# >= 2)) || {
                    printf 'Alice patch transaction: missing argument for %s\n' \
                            "$1" >&2
                    return 1
                }
                sed_args+=("$1" "$2")
                program_seen=1
                shift 2
                ;;
            --expression=*|--file=*)
                sed_args+=("$1")
                program_seen=1
                shift
                ;;
            -n|--quiet|--silent|-E|-r|-s|--regexp-extended|--separate|--zero-terminated)
                sed_args+=("$1")
                shift
                ;;
            --)
                shift
                files+=("$@")
                break
                ;;
            -*)
                printf 'Alice patch transaction: unsupported sed option: %s\n' \
                        "$1" >&2
                return 1
                ;;
            *)
                if ((program_seen == 0)); then
                    sed_args+=("$1")
                    program_seen=1
                else
                    files+=("$1")
                fi
                shift
                ;;
        esac
    done

    if ((program_seen == 0)) || ((${#files[@]} == 0)); then
        printf 'Alice patch transaction: sed -i requires an expression and files\n' >&2
        return 1
    fi

    local target resolved candidate
    for target in "${files[@]}"; do
        resolved="$(realpath -m -- "$target")" || return 1
        case "$resolved" in
            "${ALICE_PATCH_TXN_ROOT}"/*)
                ;;
            *)
                printf 'Alice patch transaction: sed target is not staged: %s\n' \
                        "$target" >&2
                return 1
                ;;
        esac

        candidate="${ALICE_PATCH_TXN_ROOT}/candidates/sed${ALICE_PATCH_TXN_SED_INDEX}"
        ((ALICE_PATCH_TXN_SED_INDEX += 1))
        if ! command sed "${sed_args[@]}" "$resolved" >"$candidate"; then
            _alice_patch_txn_remove_candidates "${candidates[@]}" "$candidate"
            return 1
        fi

        if ! cp --attributes-only --preserve=all -- "$resolved" "$candidate"; then
            _alice_patch_txn_remove_candidates "${candidates[@]}" "$candidate"
            return 1
        fi

        local cmp_status=0
        cmp -s -- "$resolved" "$candidate" || cmp_status=$?
        if ((cmp_status == 0)); then
            local original="${ALICE_PATCH_TXN_ORIGINAL_BY_STAGED[$resolved]:-$resolved}"
            printf '%s: sed 没有命中或没有产生变化: %s\n' \
                    "${ALICE_PATCH_TRANSACTION_SCRIPT:-unknown}" "$original" >&2
            _alice_patch_txn_remove_candidates "${candidates[@]}" "$candidate"
            return 2
        fi
        if ((cmp_status > 1)); then
            printf 'Alice patch transaction: failed to compare staged sed output: %s\n' \
                    "$resolved" >&2
            _alice_patch_txn_remove_candidates "${candidates[@]}" "$candidate"
            return 1
        fi

        candidates+=("$candidate")
        staged_targets+=("$resolved")
    done

    local index
    for index in "${!candidates[@]}"; do
        mv -f -- "${candidates[index]}" "${staged_targets[index]}" || return 1
    done
}

_alice_patch_txn_begin

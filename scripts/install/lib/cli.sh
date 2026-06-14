#!/usr/bin/env bash

# Shared CLI bootstrap for the top-level installer entrypoints. The entrypoint
# still owns the bash guard and usage text because those must exist before this
# library can be loaded.

cli_unknown_option() {
    local option="$1"

    echo "Error: unknown option: $option" >&2
    usage >&2
    return 1
}

cli_parse_standard_options() {
    local command="$1"
    shift

    case "$command" in
        install|uninstall)
            INSTALL_DRY_RUN=0
            INSTALL_VERBOSE=0
            ;;
        status)
            STATUS_VERBOSE=0
            ;;
        *)
            echo "Error: unknown CLI command mode: $command" >&2
            return 1
            ;;
    esac

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -n|--dry-run)
                case "$command" in
                    install|uninstall)
                        # shellcheck disable=SC2034 # Shared flag read after this sourced helper returns.
                        INSTALL_DRY_RUN=1
                        ;;
                    *) cli_unknown_option "$1" || return 1 ;;
                esac
                ;;
            -v|--verbose)
                case "$command" in
                    install|uninstall)
                        # shellcheck disable=SC2034 # Shared flag read after this sourced helper returns.
                        INSTALL_VERBOSE=1
                        ;;
                    status)
                        # shellcheck disable=SC2034 # Shared flag read after this sourced helper returns.
                        STATUS_VERBOSE=1
                        ;;
                esac
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                cli_unknown_option "$1" || return 1
                ;;
        esac
        shift
    done
}

cli_bootstrap() {
    OH_MY_ZSH_THEMES=${OH_MY_ZSH_THEMES:-"$HOME/.oh-my-zsh/themes"}

    cd "$DOTPATH" || {
        echo "Error: Could not cd to $DOTPATH"
        return 1
    }

    # Include hidden managed entries such as .claude/.agents, and make empty globs disappear.
    shopt -s nullglob dotglob

    init_installer_state
    load_installer_libraries "$@"
}

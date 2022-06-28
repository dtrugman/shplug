# ==========================================================
# General utilities
# ==========================================================

__shplug_in_zsh() {
    [[ -n "$ZSH_VERSION" ]]
}

__shplug_in_bash() {
    [[ -n "$BASH_VERSION" ]]
}

__shplug_return_str() {
    echo "$@"
}

__shplug_color() {
    local color="$1"
    shift

    local prefix="\033[${color}m"
    local suffix="\033[0m"
    echo -e "${prefix}${@}${suffix}"
}

__shplug_error() {
    local red="0;31"
    __shplug_color "$red" "$@"
}

__shplug_success() {
    local green="0;32"
    __shplug_color "$green" "$2"
}

__shplug_info() {
    echo "$@"
}

__shplug_prompt_yes_no() {
    printf "Do you approve? [y/N] "
    read answer
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

# ==========================================================
# Environment related functionality
# ==========================================================

__shplug_env_dir() {
    local env_name="$1"
    __shplug_return_str "$envs_dir/$env_name"
}

__shplug_env_exists() {
    local env_name="$1"
    local env_dir="$(__shplug_env_dir "$env_name")"
    [[ -d "$env_dir" ]]
}

__shplug_env_cd_help() {
    __shplug_info "
Change directory into an existing environment

Usage: $script_name env cd [env-name]
"
}

__shplug_env_cd() {
    if [[ $# -ne 1 || "$1" == "--help" ]]; then
        __shplug_env_cd_help
        return 2
    fi

    local env_name="$1"

    if ! __shplug_env_exists "$env_name"; then
        __shplug_error "Environment [$env_name] not found"
        return 1
    fi

    local env_dir="$(__shplug_env_dir "$env_name")"
    cd "$env_dir"
}

__shplug_env_repo() {
    local env_dir="$1"
    (cd "$envs_dir/$env_dir"; git remote get-url origin)
}

__shplug_env_enum() {
    ls -1 "$envs_dir"
}

__shplug_env_list_help() {
    __shplug_info "
List all existing environments

Usage: $script_name env list
"
}

__shplug_env_list() {
    if [[ $# -ne 0 ]]; then
        __shplug_env_list_help
        return 2
    fi

    for env_name in $(__shplug_env_enum);  do
        local env_repo="$(__shplug_env_repo "$env_name")"
        __shplug_info "$env_name -> $env_repo"
    done
}

__shplug_env_link() {
    local bak_ext="shplug.bak"

    local source_files=()
    local target_files=()
    local dirs=()

    if __shplug_in_zsh; then
        local repo_files=("${(@f)$(git ls-tree -r HEAD --name-only)}")
    elif __shplug_in_bash; then
        local repo_files=("$(git ls-tree -r HEAD --name-only)")
    fi

    for file in ${repo_files[@]}; do
        local basename="$(basename "$file")"
        local dir="$(dirname "$file")"

        # Ignore files in the first level
        if [[ "$dir" == "." ]]; then
            continue
        fi

        dir="/$dir"
        dir="${dir/\/home/$HOME}"

        target_files+=($dir/$basename)
        source_files+=($PWD/$file)

        if [[ -d "$dir" ]]; then
            continue
        fi

        if echo "$dirs" | grep -q "$dir"; then
            continue
        fi

        dirs+=($dir)
    done

    for dir in ${dirs[@]}; do
        echo "Will create directory [$dir]"
    done

    for file in ${target_files[@]}; do
        echo "Will create link [$file]"
        if [[ -f "$file" ]]; then
            echo " ! Existing file [$file] will be backed-up as [$file.$bak_ext]"
        fi
    done

    if ! __shplug_prompt_yes_no; then
        echo "Aborted by user!"
        return 1
    fi

    for dir in ${dirs[@]}; do
        if ! mkdir -p "$dir"; then
            echo "Failed to create directory [$dir]"
            return 1
        fi
    done

    local files_count=${#target_files[@]}

    if __shplug_in_zsh; then
        local from=1
        local to=$files_count
    elif __shplug_in_bash; then
        local from=0
        local to=$(($files_count - 1))
    fi

    for i in $(seq $from $to); do
        local source_file="${source_files[$i]}"
        local target_file="${target_files[$i]}"

        if [[ -f "$target_file" ]]; then
            if ! mv "$target_file" "$target_file.$bak_ext"; then
                echo "Backup [$target_file] failed, aborting!"
                return 1
            fi
        fi

        if ! ln -fs "$source_file" "$target_file"; then
            echo "Failed to create link [$target_file -> $source_file]"
            return 1
        fi
    done

    return 0
}

__shplug_env_install() {
    local installer="./install"
    if [[ -f "$installer" ]]; then
        source "$installer"
    fi
}

__shplug_env_add_help() {
    __shplug_info "
Add a new environment

Usage: $script_name env add [env-name] [env-repo]

  env-name        A custom name for this environment
  env-repo        An environment git repo to clone
"
}

__shplug_env_add() {
    if [[ $# -ne 2 ]]; then
        __shplug_env_add_help
        return 2
    fi

    local env_name="$1"
    local env_repo="$2"

    if __shplug_env_exists "$env_name"; then
        __shplug_info "Environment [$env_name] already exists"
        return 0
    fi

    local env_dir="$(__shplug_env_dir "$env_name")"
    if ! git clone "$env_repo" "$env_dir"; then
        __shplug_error "Environment [$env_name] clone failed"
        return 1
    fi

    if ! (cd $env_dir; __shplug_env_link); then
        __shplug_env_remove "$env_name"
        return 1
    fi

    if ! (cd $env_dir; __shplug_env_install); then
        __shplug_env_remove "$env_name"
        return 1
    fi

    __shplug_info "Environment [$env_name] successfully added"
    return 0
}

__shplug_env_remove_help() {
    __shplug_info "
Remove an existing environment

Usage: $script_name env remove [env-name]

  env-name       The custom name of the environment to remove
"
}

__shplug_env_remove() {
    if [[ $# -ne 1 || "$1" == "--help" ]]; then
        __shplug_env_remove_help
        return 2
    fi

    local env_name="$1"

    if ! __shplug_env_exists "$env_name"; then
        __shplug_info "Environment [$env_name] not found"
        return 0
    fi

    local env_dir="$(__shplug_env_dir "$env_name")"
    if ! rm -rf "$env_dir"; then
        __shplug_error "Environment [$env_name] removal failed"
        return 1
    fi

    __shplug_info "Environment [$env_name] successfully removed"
    return 0
}

__shplug_env_baseline() {
    if [[ ! -d "$envs_dir" ]]; then
        mkdir "$envs_dir"
    fi
}

__shplug_env_help() {
    __shplug_info "
Manage synced environments

Usage: $script_name env [command] (params)...

Commands:
  add            Add environment
  remove         Remove environment
  list           List all environments
  cd             Change directory into an environment

Run '$script_name env [command] --help' for more information on a command
"
}

__shplug_env_main() {
    if [[ $# -lt 1 ]]; then
        __shplug_env_help
        return 2
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        add)    __shplug_env_add    "$@" ;;
        remove) __shplug_env_remove "$@" ;;
        list)   __shplug_env_list   "$@" ;;
        cd)     __shplug_env_cd     "$@" ;;
        --help) __shplug_env_help        ;;
        *)      __shplug_error "Unknown command [$cmd]"; return 2 ;;
    esac
}

# ==========================================================
# Plugin related functionality
# ==========================================================

__shplug_plugin_file() {
    local plugin_name="$1"
    __shplug_return_str "$plugins_dir/$plugin_name"
}

__shplug_plugin_link() {
    local plugin_name="$1"
    __shplug_return_str "$plugins_dir/.$plugin_name"
}

__shplug_plugin_enum() {
    ls -1 "$plugins_dir"
}

__shplug_plugin_list_help() {
    __shplug_info "
List all existing plugins

Usage: $script_name plugin list
"
}

__shplug_plugin_list() {
    if [[ $# -ne 0 ]]; then
        __shplug_plugin_list_help
        return 2
    fi

    for plugin_name in $(__shplug_plugin_enum);  do
        local plugin_link="$(__shplug_plugin_link "$plugin_name")"
        local plugin_url="$(readlink "$plugin_link")"
        __shplug_info "$plugin_name -> $plugin_url"
    done
}

__shplug_plugin_load_single() {
    local plugin_name="$1"

    local plugin_file="$(__shplug_plugin_file "$plugin_name")"
    if [[ ! -f "$plugin_file" ]]; then
        __shplug_error "Plugin [$plugin_name] load failed"
        return 1
    fi

    source "$plugin_file"
}

__shplug_plugin_load_help() {
    __shplug_info "
Load (source) all existing plugins

Usage: $script_name plugin load
"
}

__shplug_plugin_load() {
    if [[ $# -ne 0 ]]; then
        __shplug_plugin_load_help
        return 2
    fi

    for plugin_name in $(__shplug_plugin_enum);  do
        __shplug_plugin_load_single "$plugin_name"
    done
}

__shplug_plugin_edit_help() {
    __shplug_info "
Manually edit an existing plugin
Editor resolution order: \$VISUAL, \$EDITOR, vi

Usage: $script_name plugin edit [plugin-name]

  plugin-name        The name of the plugin to edit
"
}

__shplug_plugin_edit() {
    if [[ $# -ne 1 || "$1" == "--help" ]]; then
        __shplug_plugin_edit_help
        return 2
    fi

    local plugin_name="$1"

    if ! __shplug_plugin_exists "$plugin_name"; then
        __shplug_error "Plugin [$plugin_name] not found"
        return 1
    fi

    local plugin_file="$(__shplug_plugin_file "$plugin_name")"

    local default_editor="vi"
    local plugin_editor="${VISUAL:-"${EDITOR:-"$default_editor"}"}"
    "$plugin_editor" "$plugin_file"
}

__shplug_plugin_exists() {
    local plugin_name="$1"
    local plugin_file="$(__shplug_plugin_file "$plugin_name")"
    local plugin_link="$(__shplug_plugin_link "$plugin_name")"
    [[ -f "$plugin_file" || -L "$plugin_link" ]]
}

__shplug_plugin_add_help() {
    __shplug_info "
Add a new plugin

Usage: $script_name plugin add [plugin-name] [plugin-url]

  plugin-name        A custom name for this plugin
  plugin-url         A remote URL from which to download the plugin
                     Use 'file:///<absolute-path>' for a local path
"
}

__shplug_plugin_add() {
    if [[ $# -ne 2 ]]; then
        __shplug_plugin_add_help
        return 2
    fi

    local plugin_name="$1"
    local plugin_url="$2"

    if __shplug_plugin_exists "$plugin_name"; then
        __shplug_info "Plugin [$plugin_name] already exists"
        return 0
    fi

    local plugin_file="$(__shplug_plugin_file "$plugin_name")"
    local plugin_link="$(__shplug_plugin_link "$plugin_name")"
    if ! curl "$plugin_url" > "$plugin_file"; then
        __shplug_error "Plugin [$plugin_name] download failed"
        return 1
    fi

    if ! ln -s "$plugin_url" "$plugin_link"; then
        __shplug_error "Plugin [$plugin_name] link creation failed"
        __shplug_plugin_remove "$plugin_name"
        return 1
    fi

    __shplug_plugin_load_single "$plugin_name"

    __shplug_info "Plugin [$plugin_name] successfully installed & loaded"
    return 0
}

__shplug_plugin_remove_help() {
    __shplug_info "
Remove an existing plugin

Usage: $script_name plugin remove [plugin-name]

  plugin-name        The name of the plugin to remove
"
}

__shplug_plugin_remove() {
    if [[ $# -ne 1 || "$1" == "--help" ]]; then
        __shplug_plugin_remove_help
        return 2
    fi

    local plugin_name="$1"

    if ! __shplug_plugin_exists "$plugin_name"; then
        __shplug_error "Plugin [$plugin_name] not found"
        return 0
    fi

    local plugin_file="$(__shplug_plugin_file "$plugin_name")"
    local plugin_link="$(__shplug_plugin_link "$plugin_name")"
    if ! rm -f "$plugin_file" "$plugin_link"; then
        __shplug_error "Plugin [$plugin_name] removal failed"
        return 1
    fi

    __shplug_info "Plugin [$plugin_name] successfully removed"
    return 0
}

__shplug_plugin_baseline() {
    if [[ ! -d "$plugins_dir" ]]; then
        mkdir "$plugins_dir"
    fi
}

__shplug_plugin_help() {
    __shplug_info "
Manage single file shell plugins (gists, scripts & more)

Usage: $script_name plugin [command] (params)...

Commands:
  add            Add plugin
  remove         Remove plugin
  list           List all plugins
  load           Source all plugin scripts
  edit           Manually edit a plugin script

Run '$script_name plugin [command] --help' for more information on a command
"
}

__shplug_plugin_main() {
    if [[ $# -lt 1 ]]; then
        __shplug_plugin_help
        return 2
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        add)    __shplug_plugin_add    "$@" ;;
        remove) __shplug_plugin_remove "$@" ;;
        list)   __shplug_plugin_list   "$@" ;;
        load)   __shplug_plugin_load   "$@" ;;
        edit)   __shplug_plugin_edit   "$@" ;;
        --help) __shplug_plugin_help        ;;
        *)      __shplug_error "Unknown plugin command [$cmd]"; return 2 ;;
    esac
}

# ==========================================================
# Import
# ==========================================================

__shplug_import_help() {
    __shplug_info "
Easily import configuration from a file
Runs every line in a file as if called '$script_name <line>'

Usage: $script_name import [config-file]
"
}

__shplug_import_main() {
    if [[ $# -ne 1 || "$1" == "--help" ]]; then
        __shplug_import_help
        return 2
    fi

    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        __shplug_error "Config file [$config_file] doesn't exist!"
        return 1
    fi

    # Use intermediate array to allow interactive user prompts while processing commands.
    # Using nested 'read'-s doesn't work well.
    local commands=()
    while IFS="" read -r line || [ -n "$line" ]
    do
        commands+=("$line")
    done < "$config_file"

    for command in "${commands[@]}"; do
        # No quotes on purpose, we wanna unpack the line
        __shplug_main $command
    done
}

# ==========================================================
# Update
# ==========================================================

__shplug_update_help() {
    __shplug_info "
Update $script_name to latest version

Usage: $script_name upgrade
"
}

__shplug_update_main() {
    if [[ $# -ne 0 ]]; then
        __shplug_update_help
        return 2
    fi

    (cd $app_dir; git pull)
}

# ==========================================================
# Version
# ==========================================================

__shplug_version() {
    __shplug_info "shplug v$script_version"
}

# ==========================================================
# Main
# ==========================================================

__shplug_main_help() {
    __shplug_info "
Your new shell environment manager

Usage: $script_name [command] (params)...

Commands:
  env            Manage environments
  plugin         Manage plugins
  import         Import environments and plugins from file
  update         Update shplug to the latest version
  version        Print version information and exit

Run '$script_name [command] --help' for more information on a command
"
}

__shplug_main() {
    if [[ $# -lt 1 ]]; then
        __shplug_main_help
        return 2
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        version) __shplug_version          ;;
        plugin)  __shplug_plugin_main "$@" ;;
        env)     __shplug_env_main    "$@" ;;
        import)  __shplug_import_main "$@" ;;
        update)  __shplug_update_main "$@" ;;
        --help)  __shplug_main_help        ;;
        *)       __shplug_error "Unknown shplug command [$cmd]"; return 2 ;;
    esac
}

shplug() {
    declare -r script_version="0.1.0"
    declare -r script_name="shplug"

    declare -r root_dir="$HOME/.$script_name"
    declare -r app_dir="$root_dir/app"

    declare -r plugins_dir="$root_dir/plugin"
    __shplug_plugin_baseline

    declare -r envs_dir="$root_dir/env"
    __shplug_env_baseline

    __shplug_main "$@"
}

shplug plugin load

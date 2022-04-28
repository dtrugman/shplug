# ==========================================================
# General utilities
# ==========================================================

__shplug_shell() {
    if [[ -n "$ZSH_VERSION" ]]; then
        __shplug_return_str "zsh"
    elif [[ -n "$BASH_VERSION" ]]; then
        __shplug_return_str "bash"
    else
        __shplug_return_str ""
    fi
}

__shplug_in_zsh() {
    [[ "$shell" == "zsh" ]]
}

__shplug_in_bash() {
    [[ "$shell" == "bash" ]]
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

__shplug_debug() {
    if [[ "$verbose" != "0" ]]; then
        echo "$@"
    fi
}

__shplug_prompt_yes_no() {
    printf "Do you approve? [y/N] "
    read answer
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

# ==========================================================
# Environment related functionality
# ==========================================================

__shplug_env_hint() {
    __shplug_info "Usage: $script_name env $@"
}

__shplug_env_dir() {
    local plugin_name="$1"
    __shplug_return_str "$envs_dir/$plugin_name"
}

__shplug_env_cd() {
    if [[ $# -ne 1 ]]; then
        __shplug_env_hint "cd [env-name]"
        return 2
    fi

    local env_name="$1"
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

__shplug_env_list() {
    if [[ $# -ne 0 ]]; then
        __shplug_env_hint "list"
        return 2
    fi

    for env_name in $(__shplug_env_enum);  do
        local env_repo="$(__shplug_env_repo "$env_name")"
        __shplug_info "$env_name -> $env_repo"
    done
}

__shplug_env_exists() {
    local env_dir="$1"
    [[ -d "$env_dir" ]]
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
        dir="${dir/\/home/"$HOME"}"

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

__shplug_env_add() {
    if [[ $# -ne 2 ]]; then
        __shplug_env_hint "add [env-name] [env-repo]"
        return 2
    fi

    local env_name="$1"
    local env_repo="$2"
    __shplug_debug "Adding plugin environment [$env_name] from [$env_repo]"

    local env_dir="$(__shplug_env_dir "$env_name")"
    if __shplug_env_exists "$env_dir"; then
        __shplug_info "Environment [$env_name] already exists"
        return 0
    fi

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

__shplug_env_remove() {
    if [[ $# -ne 1 ]]; then
        __shplug_env_hint "remove [env-name]"
        return 2
    fi

    local env_name="$1"
    __shplug_debug "Removing plugin environment [$env_name]"

    local env_dir="$(__shplug_env_dir "$env_name")"
    if ! __shplug_env_exists "$env_dir"; then
        __shplug_info "Environment [$env_name] not found"
        return 0
    fi

    if ! rm -rf "$env_dir"; then
        __shplug_error "Environment [$env_name] removal failed"
        return 1
    fi

    __shplug_info "Environment [$env_name] successfully removed"
    return 0
}

__shplug_env_baseline() {
    if [[ ! -d "$envs_dir" ]]; then
        __shplug_debug "Creating missing environments dir"
        mkdir "$envs_dir"
    fi
}

__shplug_env_main() {
    if [[ $# -lt 1 ]]; then
        __shplug_env_hint "[add|remove|cd|list] (params)..."
        return 2
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        add)
            __shplug_env_add "$@"
            ;;

        remove)
            __shplug_env_remove "$@"
            ;;

        cd)
            __shplug_env_cd "$@"
            ;;

        list)
            __shplug_env_list
            ;;

        *)
            __shplug_error "Unknown command [$cmd]"
            return 2;;
    esac
}

# ==========================================================
# Plugin related functionality
# ==========================================================

__shplug_plugin_hint() {
    __shplug_info "Usage: $script_name plugin $@"
}

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

__shplug_plugin_list() {
    if [[ $# -ne 0 ]]; then
        __shplug_plugin_hint "list"
        return 2
    fi

    for plugin_name in $(__shplug_plugin_enum);  do
        local plugin_link="$(__shplug_plugin_link "$plugin_name")"
        local plugin_url="$(readlink "$plugin_link")"
        __shplug_info "$plugin_name -> $plugin_url"
    done
}

__shplug_plugin_load() {
    local plugin_name="$1"
    local plugin_file="$(__shplug_plugin_file "$plugin_name")"

    if [[ ! -f "$plugin_file" ]]; then
        __shplug_error "Plugin [$plugin_name] load failed"
        return 1
    fi

    __shplug_debug "Loading plugin [$plugin_name]"
    source "$plugin_file"
}

__shplug_plugin_load_all() {
    if [[ $# -ne 0 ]]; then
        __shplug_plugin_hint "load"
        return 2
    fi

    for plugin_name in $(__shplug_plugin_enum);  do
        __shplug_plugin_load "$plugin_name"
    done
}

__shplug_plugin_edit() {
    if [[ $# -ne 1 ]]; then
        __shplug_plugin_hint "edit [plugin-name]"
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

__shplug_plugin_add() {
    if [[ $# -ne 2 ]]; then
        __shplug_plugin_hint "add [plugin-name] [plugin-url]"
        return 2
    fi

    local plugin_name="$1"
    local plugin_url="$2"
    __shplug_debug "Adding plugin [$plugin_name] from [$plugin_url]"

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
        rm -f "$plugin_file"
        __shplug_error "Plugin [$plugin_name] link creation failed"
        return 1
    fi

    __shplug_plugin_load "$plugin_name"

    __shplug_info "Plugin [$plugin_name] successfully installed & loaded"
    return 0
}

__shplug_plugin_remove() {
    if [[ $# -ne 1 ]]; then
        __shplug_plugin_hint "remove [plugin-name]"
        return 2
    fi

    local plugin_name="$1"
    __shplug_debug "Removing plugin [$plugin_name]"

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
        __shplug_debug "Creating missing plugins dir"
        mkdir "$plugins_dir"
    fi
}

__shplug_plugin_main() {
    if [[ $# -lt 1 ]]; then
        __shplug_plugin_hint "[add|remove|load|edit|list] (params)..."
        return 2
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        add)
            __shplug_plugin_add "$@"
            ;;

        remove)
            __shplug_plugin_remove "$@"
            ;;

        load)
            __shplug_plugin_load_all
            ;;

        edit)
            __shplug_plugin_edit "$@"
            ;;

        list)
            __shplug_plugin_list
            ;;

        *)
            __shplug_error "Unknown command [$cmd]"
            return 2;;
    esac
}

# ==========================================================
# Import
# ==========================================================

__shplug_import_hint() {
    __shplug_info "Usage: $script_name import $@"
}

__shplug_import_main() {
    if [[ $# -ne 1 ]]; then
        __shplug_import_hint "[config-file]"
        return 2
    fi

    local config_file="$1"
    __shplug_debug "Importing config file [$config_file]"

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

__shplug_update_hint() {
    __shplug_info "Usage: $script_name upgrade $@"
}

__shplug_update_main() {
    if [[ $# -ne 0 ]]; then
        __shplug_update_hint
        return 2
    fi

    (cd $app_dir; git pull)
}

# ==========================================================
# Main
# ==========================================================

__shplug_version() {
    __shplug_info "Shplug version $script_version"
}

__shplug_main() {
    if [[ $# -lt 1 ]]; then
        __shplug_info "Usage: $script_name [version|plugin|env|import|update] (params)..."
        return 2
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        version)
            __shplug_version
            ;;

        plugin)
            __shplug_plugin_main "$@"
            ;;

        env)
            __shplug_env_main "$@"
            ;;

        import)
            __shplug_import_main "$@"
            ;;

        update)
            __shplug_update_main "$@"
            ;;

        *)
            __shplug_error "Unknown command [$cmd]"
            return 2;;
    esac
}

shplug() {
    declare -r verbose="${VERBOSE:-0}"
    declare -r shell="$(__shplug_shell)"

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

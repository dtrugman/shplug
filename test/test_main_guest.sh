# This is the main script for running the script from WITHIN THE CONTAINER.

test_title() {
    echo "==============================================================="
    echo "TEST #$test_index: $@"
    echo "==============================================================="
    ((test_index++))
}

color_echo() {
    local color="$1"
    shift

    local prefix="\033[${color}m"
    local suffix="\033[0m"
    echo -e "${prefix}${@}${suffix}"
}

failure() {
    local red="0;31"
    color_echo "$red" "!!! ERROR: $@"
}

success() {
    local green="0;32"
    color_echo "$green" "===> SUCCESS"
}

test_plugin_prepare() {
    cat <<EOF >> "$plugin_path"
$plugin_name() {
    echo $plugin_name > $plugin_output
}
EOF
    if [[ $? -ne 0 ]]; then
        failure "Failed to write test plugin"
        return 1
    fi

    return 0
}

test_plugin() {
    local plugin_name="plugme"
    local plugin_path="$temp_dir/$plugin_name"
    local plugin_output="$plugin_path.output"
    local plugin_url="file://$plugin_path"

    test_plugin_prepare || return 1

    if ! shplug plugin add "$plugin_name" "$plugin_url"; then
        failure "Failed to add plugin"
        return 1
    fi

    if ! "$plugin_name"; then
        failure "Failed to invoke plugin"
        return 1
    fi

    if [[ ! -f "$plugin_output" ]]; then
        failure "Missing output file"
        return 1
    fi

    if [[ "$(cat $plugin_output)" != "$plugin_name" ]]; then
        failure "Unexpected output file content"
        return 1
    fi

    if ! shplug plugin remove "$plugin_name"; then
        failure "Failed to remove plugin"
        return 1
    fi

    if "$SHELL" -c "$plugin_name"; then
        failure "Plugin still available after removal"
        return 1
    fi

    success
    return 0
}

test_env_prepare_gitrepo() {
    if ! mkdir "$env_temp_repo"; then
        failure "Couldn't create test env repo"
        return 1
    fi

    # Only to avoid noisy prints
    if ! git config --global init.defaultBranch "main"; then
        failure "Failed to set initial branch name"
        return 1
    fi

    if ! git config --global user.email "temp@email.com"; then
        failure "Failed to set git initial user email"
        return 1
    fi

    if ! git config --global user.name "Initial Name"; then
        failure "Failed to set git initial user name"
        return 1
    fi

    if ! git init "$env_temp_repo"; then
        failure "Couldn't init test env repo"
        return 1
    fi

    return 0
}

test_env_prepare_directories() {
    declare -a directories=("$env_temp_home" "$env_temp_bin")
    for dir in "${directories[@]}"; do
        if ! mkdir -p "$dir"; then
            failure "Couldn't create test env dir [$env_temp_home]"
            return 1
        fi
    done

    return 0
}

test_env_prepare_gitconfig() {
    cat <<EOF >> "$env_temp_gitconfig"
[user]
    email = "$env_git_email"
    name = "$env_git_name"
EOF
    if [[ $? -ne 0 ]]; then
        failure "Failed to write env gitconfig"
        return 1
    fi

    return 0
}

test_env_prepare_echoer() {
    cat <<EOF >> "$env_temp_echoer"
echo "$env_echoer_output"
EOF
    if [[ $? -ne 0 ]]; then
        failure "Failed to write env echoer"
        return 1
    fi

    if ! chmod +x "$env_temp_echoer"; then
        failure "Failed to set echoer as executable"
        return 1
    fi

    return 0
}

test_env_prepare_commit() {
    if ! (cd "$env_temp_repo"; git add *; git commit -m "Initial commit"); then
        failure "Failed to commit changes"
        return 1
    fi

    return 0
}

test_env() {
    local env_name="envit"

    local env_relative_gitconfig=".gitconfig"
    local env_relative_bin="local/bin"
    local env_echoer="echoer"

    local env_echoer_output="ECHO!"

    local env_temp_repo="$temp_dir/$env_name"
    local env_temp_home="$env_temp_repo/home"
    local env_temp_gitconfig="$env_temp_home/$env_relative_gitconfig"
    local env_temp_bin="$env_temp_home/$env_relative_bin"
    local env_temp_echoer="$env_temp_bin/$env_echoer"

    local env_deployed_home="$HOME"
    local env_deployed_gitconfig="$env_deployed_home/$env_relative_gitconfig"
    local env_deployed_bin="$env_deployed_home/$env_relative_bin"
    local env_deployed_echoer="$env_deployed_bin/$env_echoer"
    local env_deployed_tool_config="$env_deployed_bin/$env_tool_config"

    local env_git_email="test@shplug.com"
    local env_git_name="Test Env"

    test_env_prepare_gitrepo || return 1
    test_env_prepare_directories || return 1
    test_env_prepare_gitconfig || return 1
    test_env_prepare_echoer || return 1
    test_env_prepare_commit || return 1

    if ! yes | shplug env add "$env_name" "$env_temp_repo"; then
        failure "Failed to add env"
        return 1
    fi

    if [[ ! -f "$HOME/$env_relative_gitconfig.shplug.bak" ]]; then
        failure "Existing gitconfig not backed-up as expected"
        return 1
    fi

    local actual_git_email="$(git config user.email)"
    if [[ "$actual_git_email" != "$env_git_email" ]]; then
        failure "Unexpected git user.email value [$git_email]"
        return 1
    fi

    local actual_git_name="$(git config user.name)"
    if [[ "$actual_git_name" != "$env_git_name" ]]; then
        failure "Unexpected git user.name value [$git_name]"
        return 1
    fi

    local actual_echoer_output="$($env_deployed_echoer)"
    if [[ "$actual_echoer_output" != "$env_echoer_output" ]]; then
        failure "Unexpected echoer output [$actual_echoer_output]"
        return 1
    fi

    if ! shplug env remove "$env_name"; then
        failure "Failed to remove env"
        return 1
    fi

    local links=("$env_deployed_gitconfig" "$env_deployed_echoer")
    for link in "${links[@]}"; do
        if [[ ! -L "$link" ]]; then
            failure "Link [$env_deployed_gitconfig] unexpectedly unlinked during remove"
            return 1
        fi
    done

    if [[ ! -d "$env_deployed_bin" ]]; then
        failure "Dir [$env_deployed_bin] unexpectedly unlinked during remove"
        return 1
    fi

    success
    return 0
}

test_help_menu() {
    if ! shplug "$@" | grep -q "Usage"; then
        failure "'shplug $@' didn't show help menu"
        return 1
    fi
}

test_help_menus() {
    test_help_menu "--help" || return 1

    test_help_menu "plugin" || return 1
    test_help_menu "plugin" "--help" || return 1
    test_help_menu "plugin" "add" "--help" || return 1
    test_help_menu "plugin" "remove" "--help" || return 1
    test_help_menu "plugin" "list" "--help" || return 1
    test_help_menu "plugin" "load" "--help" || return 1
    test_help_menu "plugin" "edit" "--help" || return 1

    test_help_menu "env" || return 1
    test_help_menu "env" "--help" || return 1
    test_help_menu "env" "add" "--help" || return 1
    test_help_menu "env" "remove" "--help" || return 1
    test_help_menu "env" "list" "--help" || return 1
    test_help_menu "env" "cd" "--help" || return 1

    test_help_menu "import" "--help" || return 1

    test_help_menu "update" "--help" || return 1

    success
    return 0
}

main() {
    declare -r temp_dir="/tmp"
    declare -r guest_root="/app"

    declare test_index=1

    # TODO: Find workaround
    # Because we're installing shplug when creating the container,
    # when we run the script with a non-interactive shell,
    # the .XXXrc file is not sourced
    source "${HOME}/.${SHELL}rc"

    test_title "Test help menus"
    test_help_menus || true

    test_title "Test plugin"
    test_plugin || true

    test_title "Test env"
    test_env || true

    return 0
}

main "$@"

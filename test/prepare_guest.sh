failure() {
    echo "ERROR: $@"
}

success() {
    echo "==> SUCCESS"
}

install_shplug() {
    local install_script="install"
    local remote_repo='https:\/\/github.com\/dtrugman\/shplug.git'
    local local_repo='\/app'
    sed "s/$remote_repo/$local_repo/g" "$install_script" > "$temp_dir/$install_script"
    if ! source <(cat "$temp_dir/$install_script"); then
        failure "Failed to run install script"
        return 1
    fi

    source "$HOME/.${shell}rc"

    success
    return 0
}

main() {
    declare -r shell="$SHELL"
    declare -r temp_dir="/tmp"

    install_shplug
}

main "$@"

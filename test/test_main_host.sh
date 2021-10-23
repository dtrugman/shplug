#/bin/bash

test_shell() {
    local shell="$1"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Testing shplug for shell: $shell"
    echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    docker build -t "$image_name:$shell" "$host_root/test/$shell"
    docker run --rm -v "$host_root:$guest_root" "$image_name:$shell"
}

main() {
    declare -r host_root="$PWD"
    declare -r guest_root="/app"

    if [[ ! -d "$host_root/.git" ]]; then
        echo "You seem to be running the tests from the wrong directory."
        echo "Please run the tests using the './test.sh' script from the root directory!"
        return 1
    fi

    declare -r image_name="shplug"

    test_shell "bash"
    test_shell "zsh"
}

main "$@"

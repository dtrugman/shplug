#/bin/bash

docker_build() {
    local shell="$1"
    shift

    docker build \
        --build-arg "shell=$shell" \
        --tag "$repo_name/$shell:$version" \
        --file "./test/Dockerfile" \
        "$@" "."
}

manual_test() {
    local shell="$1"

    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Building and running docker for manual testing [$shell]"
    echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

    docker_build "$shell"

    docker run -it --rm "$repo_name/$shell:$version"
}

integration_test() {
    local shell="$1"

    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Building and running docker for integration testing [$shell]"
    echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

    docker_build "$shell"

    docker run --rm "$repo_name/$shell:$version" "/bin/$shell" "./test/test_main_guest.sh"
}

hint() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  integration     Run full integration tests"
    echo "  bash            Run interactive bash container for manual tests"
    echo "  zsh             Run interactive zsh container for manual tests"
    echo ""
}

main() {
    declare -r guest_root="/app"
    declare -r repo_name="shplug"
    declare -r version="latest"

    if [[ ! -d "./.git" ]]; then
        echo "You seem to be running the tests from the wrong directory."
        echo "Please run the tests using the './test.sh' script from the root directory!"
        return 1
    fi

    if [[ "$#" -ne 1 ]]; then
        hint
        return 2
    fi

    declare -r command="$1"
    case "$command" in
        integration)
            integration_test "bash"
            integration_test "zsh"
            ;;

        bash)
            manual_test "bash"
            ;;

        zsh)
            manual_test "zsh"
            ;;

        *)
            hint
            ;;
    esac
}

main "$@"

#!/bin/bash

main() {
    # Run the test script from the git root directory
    # We need to mount the entire git repo into the container

    ./test/test_main_host.sh
}

main "$@"

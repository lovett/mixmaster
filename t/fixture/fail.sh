#!/usr/bin/env sh

# This curl command receives a mangled URL that will emit the error
# mesage "Malformed input to a URL function" and cause the script to
# fail.

curl 'http://localhost hello world'

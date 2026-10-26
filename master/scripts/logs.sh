#!/bin/sh

. "$(dirname -- "$0")/lib.sh"

require_cmd docker
compose logs -f "$@"

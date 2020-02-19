#!/bin/sh

cmd="vault-${1}.sh"
shift

exec "${cmd}" "$@"

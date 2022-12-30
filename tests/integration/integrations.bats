#!/bin/bash bats

setup(){
	load 'test_helper/bats-support/load'
	load 'test_helper/bats-assert/load'
	DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
	PATH="$DIR/..:$PATH"/

	mkdir -p tmp/a tmp/remote tmp/cache
	cat <<-EOF > autosync.conf
	local_path=tmp/a
	remote_path=tmp/remote
	EOF
	export AUTOSYNC_TEST='interface_test'
}

teardown(){
	rm -rf tmp autosync.conf
}

# Positional Arguments

@test "autosync-run (use local autosync.conf)" {
	run ./autosync-run.sh
	assert_output -e "Using config '.*autosync.conf'"
	refute_output -p "Local Path doesn't exist or Remote Path is not configured"
	assert_output -p 'LocaPath=tmp/a; RemotePath=tmp/remote'
}
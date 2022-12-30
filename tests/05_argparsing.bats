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

@test "autosync-run (use misconfigued local autosync.conf)" {
	rm -rf tmp/a
	run ./autosync-run.sh
	assert_output -e "Using config '.*autosync.conf'"
	assert_output -p "Local Path doesn't exist or Remote Path is not configured"
}

@test "autosync-run (use linux system autosync.conf)" {
	skip 'needs to be run inside an isolated environemnt, like docker'
	run ./autosync-run.sh
	assert_output -e "Using config '.*autosync.conf'"
	refute_output -p "Local Path doesn't exist or Remote Path is not configured"
	assert_output -p 'LocaPath=tmp/a; RemotePath=tmp/remote'
}

@test "autosync-run config-file (use custom valid config file)" {
	cat <<-EOF > myconfig
	local_path='tmp/a'
	remote_path='tmp/remote'
	EOF
	run ./autosync-run.sh myconfig
	assert_output -e "Using config '.*'"
	refute_output -p "Local Path doesn't exist or Remote Path is not configured"
	rm myconfig
}

@test "autosync-run config-file (use custom invalid config file)" {
	cat <<-EOF > myconfig
	foo_path='tmp/a'
	remote_path='tmp/remote'
	EOF
	run ./autosync-run.sh myconfig
	assert_output -e "Using config '.*'"
	assert_output -p "Local or Remote path not defined"
	rm myconfig
}

@test "autosync-run tmp/a tmp/remote (use custom local/remote paths)" {
	run ./autosync-run.sh tmp/a tmp/remote
	refute_output -p "Using config '"
	assert_output 'LocaPath=tmp/a; RemotePath=tmp/remote'
}

# bats test_tags=x
@test "autosync-run -v tmp/a tmp/remote" {
	run ./autosync-run.sh tmp/a tmp/remote -v
	refute_output -p "Using config '"
	assert_output 'LocaPath=tmp/a; RemotePath=tmp/remote'
}
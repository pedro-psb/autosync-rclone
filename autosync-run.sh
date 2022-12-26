#!/bin/bash
# Runs rclone bisync with automatic error handling for common scenarios:
# - First run of bisync
# - Empty directories

help(){
	cat <<- EOF
	Usage: autosync [CONFIG-FILE] [OPTIONS]
	Autosync is a utility to automate the 'rclone bisync' command.

	By default, it works with a config file that will be looked up on:
	- Current folder as 'autosync.conf'
	- Default on linux-pc: '~/.config/autosync/autosync.conf'
	- Default on android-termux: 'TODO'

	Options:
	  -h, --help		Show this help
	  -q, --quiet		Quiet mode
	  -t, --test		Test mode
	  ---			I need to design the TUI better
		
	EOF
	exit 0
}
script_debug=1
script_test=1
script_verbose=0
log_file='autosync.log'

rclone_flags=()
bisync_flags=() # means bisync flags

if [[ $script_test = 1 ]]; then
	bisync_flags+=(--workdir=tmp/cache)
	rclone_flags+=(--config rclone.conf)
fi

debugme() {
		[[ $script_debug = 1 ]] && "$@" || :
}

logme(){
	# logme [msg]
	echo $1 | tee -a $log_file
}

logmev(){
	# logme [heredoc] [file-to-cat]
	if [[ $script_verbose = 1 ]]; then
		awk '{print "    "$0}' <<- EOF | tee -a $log_file
			$(date)
			[ $1 ]
			$(cat $2)
			---
		EOF
	else
		awk '{print "    "$0}' <<- EOF >> $log_file
			$(date)
			[ $1 ]
			$(cat $2)
			---
		EOF
	fi
}

bisync(){
		# bisync [local] [remote] [flags]
		rclone "${rclone_flags[@]}" \
				bisync \
				$1 $2 \
				--verbose \
				"${bisync_flags[@]}" \
				$3
}

autosync-run(){
		# autosync-run [local] [remote] [flags]
		logme 'Running autosync-run'
		tmp_file="autosync.tmp"

		if bisync $1 $2 &> $tmp_file; then
				logmev 'autosync.tmp - sucess case' autosync.tmp
				logme 'Autosync succeded'
				return 0
		fi
		logmev 'autosync.tmp - before retry' autosync.tmp

		# Deal with no prior run case (.lst doesn't exit on cache folder)
		if grep -q 'error: cannot find prior Path1 or Path2 listings' "$tmp_file"; then
				logme 'No prior sync. Retrying with --resync'
				rclone test makefile 1 $1/rclone_keep &> /dev/null
				if bisync $1 $2 --resync &> $tmp_file; then
						logme 'Autosync first run succeded'
				else
						logme "Autosync first run failed"
				fi
				logmev 'autosync.tmp - after retry' autosync.tmp
		fi

		# Deal with too many deletes
		if grep -q 'Safety abort: too many deletes' "$tmp_file"; then
				logme 'Safety abort: too many deletes. Creating error file'

				# create readable error message on /errors
				rclone "${rclone_flags[@]}" copyto $tmp_file "$2/autosync.error.$(date)" &>> autosync.tmp
				logmev 'autosync.tmp - after safety abort' autosync.tmp
		fi
}

main(){
	[[ ${#} -eq 0 ]] && help
	while getopts ":vt" opt; do
		case $opt in
			v)  script_verbose=1;;
			t)  script_test=1;;
			/?) echo "Invalid option: -$OPTARG"; exit 1;;
		esac
	done

	autosync-run "$@"
	logme ''
	rm autosync.tmp
}

main "$@"

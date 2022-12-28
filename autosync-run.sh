#!/bin/bash
# Runs rclone bisync with automatic error handling for common scenarios:
# - First run of bisync
# - Empty directories

help(){
	cat <<- EOF
	Usage:  autosync [OPTIONS]
	        autosync <config-file> [OPTIONS]
	        autosync <local> <remote> [OPTIONS]

	Autosync is a utility to automate the 'rclone bisync' command.

	By default, it works with a config file that will be looked up on:
	- Current folder as 'autosync.conf'
	- Default on linux-pc: '~/.config/autosync/autosync.conf'
	- Default on android-termux: 'TODO'

	It will create a log file in the current folder.

	Options:
	  -h, --help		Show this help
	  -q, --quiet		Quiet mode
	  -t, --test		Test mode
		
	EOF
}

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
			$( [[ $# -eq 2 ]] && cat "$2")
			---
		EOF
	else
		awk '{print "    "$0}' <<- EOF >> $log_file
			$(date)
			[ $1 ]
			$( [[ $# -eq 2 ]] && cat "$2")
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
	script_debug=1
	script_test='test'
	script_verbose=1
	log_file='autosync.log'

	rclone_flags=()
	bisync_flags=()

	local_path=''
	remote_path=''

	# Handle Options
	while true; do
		case "$1" in
			-h | --help)
				help;;
			-q | --quiet)
				echo "Quiet mode";
				shift;;
			-t | --test)
				echo "Test mode";
				shift;;
			-*)
				echo "Unknow option $1"; help; exit 1;;
			*)
				break;;	
		esac
	done

	# Handle Positional Arguments
	case "$#" in
		0) # Auto seek config
			config_paths=(
				"$PWD/autosync.conf" \
				"$HOME/autosync/autosync.conf" \
				)
			config_file=''
			for p in "${config_paths[@]}"; do 
				if [[ -f $p ]]; then
					config_file="$p"
					source "$p"
					logme "Using config '$p'"
					break
				fi
			done
			[[ $config_file = '' ]] && echo 'Unable to find .conf file' && help
			;;
		1) # Config path provided
			[[ -f $1 ]] && source "$1"
			logme "Using config '$1'"
			;;
		2) # remote and local provided
			local_path=$1
			remote_path=$2
			;;
	esac

	# Check if local_path and remote_path are valid
	[[ $local_path = '' || $remote_path = '' ]] && echo 'Local or Remote path not defined' && exit 1
	logme "Local Path is: '$local_path'; Remote Path is: '$remote_path'"

	exit
	# General setup
	if [[ $script_test = 'test' ]]; then
		bisync_flags+=(--workdir=tmp/cache)
		rclone_flags+=(--config rclone.conf)
	fi
	
	# Execute program
	autosync-run "$@"
	logme ''
	rm autosync.tmp
}

main "$@"

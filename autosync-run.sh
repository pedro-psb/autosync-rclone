#!/bin/bash
# Runs rclone bisync with automatic error handling for common scenarios:
# - First run of bisync
# - Empty directories
# set -eox pipefail

script_debug=1
script_verbose=''
log_file='autosync.log'

[[ -n $AUTOSYNC_DEBUG ]] && set -x;

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

logme(){
	# logme [msg]
	echo "$1" | tee -a $log_file
}

# verbose mode logging
# usage: logmev <message> [OPTIONS]
# 	-d, --date	Prints date at the beginning
#	-f, --file	Inform file to cat and add after message
logmev(){
	[[ $# = 0 ]] && return 1;

	# Parse Options
	local message=''
	local file_text=''
	local args=()

	while true; do
		case $1 in
			-d | --date)
				# Add date
				message+="    [ $(date) ]\n";
				shift;;
			-f | --file)
				#
				file_text=$(cat "$2");
				shift 2;;
			-*) shift;;
			*)
				args+=("$1");
				shift;;
		esac
		[[ -z $1 ]] && break;
	done

	# Add message with left pad
	message+="    [ ${args[0]} ]"

	# Add optional file_text with left pad
	if [[ -n $file_text ]]; then
		message+="\n"
		message+=$(awk '{print "    "$0}' <<- EOF
			$file_text
		EOF
		)
	fi

	# Print message
	if [[ $script_verbose = 'verbose' ]]; then
		echo -e "$message" | tee -a $log_file
	else
		echo -e "$message" &>> $log_file
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
				logmev 'autosync.tmp - sucess case' -f autosync.tmp -d
				logme 'Autosync succeded'
				return 0
		fi
		logmev 'autosync.tmp - before retry' -f autosync.tmp

		# Deal with no prior run case (.lst doesn't exit on cache folder)
		if grep -q 'error: cannot find prior Path1 or Path2 listings' "$tmp_file"; then
				logme 'No prior sync. Retrying with --resync'
				rclone test makefile 1 $1/rclone_keep &> /dev/null
				if bisync $1 $2 --resync &> $tmp_file; then
						logme 'Autosync first run succeded'
				else
						logme "Autosync first run failed"
				fi
				logmev 'autosync.tmp - after retry' -f autosync.tmp
		fi

		# Deal with too many deletes
		if grep -q 'Safety abort: too many deletes' "$tmp_file"; then
				logme 'Safety abort: too many deletes. Creating error file'

				# create readable error message on /errors
				rclone "${rclone_flags[@]}" copyto $tmp_file "$2/autosync.error.$(date)" &>> autosync.tmp
				logmev 'autosync.tmp - after safety abort' -f autosync.tmp
		fi
}


# Provide this style of parsing:
#   command [OPTIONS] [non-flag-args]
#
# any flags after the first non-flag is ignored
argparse(){
  : :: Getting valid options ::
  while true; do
	case $1 in
		-h | --help)
			help; exit 0;;
		-v | --verbose)
			script_verbose='verbose'
			shift;;
		-*)
			echo "Unknow option $1"; help; exit 1;;
		*) break;;
	esac
  done

	: :: Discarding OPTIONS after argv ::
  argv=()
  while [[ -n "$1" ]]; do
	case $1 in
	  -*) shift;;
	  *) argv+=("$1"); shift;;
	esac
  done
  argc="${#argv[@]}"

  : :: Interpreting cleaned argv :: 
  case $argc in
	0) # Auto seek config
		config_paths=(
			"$PWD/autosync.conf" \
			"$HOME/.config/autosync/autosync.conf" \
			"$HOME/.autosync/autosync.conf" \
			)
		config_file=''
		for p in "${config_paths[@]}"; do 
			if [[ -f $p ]]; then
				config_file="$p"
				source "$config_file"
				logme "Using config '$p'"
				break
			fi
		done
		[[ $config_file = '' ]] && echo 'Unable to find .conf file' && help && exit 1;
		;;
	1) # Config path provided
		[[ -f ${argv[0]} ]] && source "${argv[0]}"
		logme "Using config '${args[0]}'"
		;;
	2) # remote and local provided
		local_path="${argv[0]}"
		remote_path="${argv[1]}"
		;;
  esac
}


main(){
	rclone_flags=()
	bisync_flags=()

	local_path=''
	remote_path=''

	argparse "$@"

	# Check if local_path and remote_path are valid
	[[ $local_path = '' || $remote_path = '' ]] && echo 'Local or Remote path not defined' && exit 1
	logmev "Local Path is: '$local_path'; Remote Path is: '$remote_path'"
	if ! rclone bisync "$local_path" "$remote_path" --resync --force --dry-run &>>$log_file; then
		echo "Local Path doesn't exist or Remote Path is not configured"
		exit 1
	fi

	# Test setup
	if [[ $AUTOSYNC_TEST != '' ]]; then
		bisync_flags+=(--workdir=tmp/cache)
		rclone_flags+=(--config rclone.conf)
	fi

	if [[ $AUTOSYNC_TEST = 'interface_test' ]]; then
		echo "LocaPath=$local_path; RemotePath=$remote_path"
		[[ $script_verbose = 'verbose' ]] && echo "Verbose Mode"
		exit 0
	fi
	
	# Execute program
	autosync-run "$local_path" "$remote_path"
	logme ''
	rm autosync.tmp
}

# Allow sourcing this file without executing main (for testing out functions)
__name__="$(basename $0)" 
if [[ "$__name__" = "autosync-run" || "$__name__" = "autosync-run.sh" ]]; then
	main "$@"
fi

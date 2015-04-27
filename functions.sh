#!/bin/bash

PROGIMG="${0}"
XIFS=$IFS
#IFS=$' '
selected=""
options=""

execution_premission()
{
	local AMSURE
	if [ -n "${1}" ] ; then
		echo
		read -n 1 -p "${1} (y/[a]): " AMSURE
	else
		read -n 1 AMSURE
	fi
	echo "" 1>&2
	if [ "${AMSURE}" = "y" ] ; then
		return 0
	else
		return 1
	fi
}

decrunch()
{
	test $# -gt 0 || { echo "${FUNCNAME[0]}: No params given"; return 1; }
	local params=($@)
	local params_count=${#params[*]}
	local src="${params[params_count-2]}"
	local dst="${params[params_count-1]}"
	echo ${params} ${params_count} ${src} ${dst}
	local cmd=""
	if [ -f "${src}" ]; then
		case "${src}" in
			*.tar) cmd="tar -xp -C ${dst} ";;
            *.tar.bz2,*.tbz2) cmd="tar -xpj -C ${dst} ";;
            *.tar.gz,*.tgz) cmd="tar -xpz -C ${dst} ";;
            *.tar.xz) cmd="tar -tpJ -C ${dst} ";;
            *.bz2) cmd="bunzip2 > ${dst} ";;
            *.deb) cmd="ar x > {dst} ";;
            *.gz) cmd="gunzip > ${dst} ";;
            *.rar) cmd="unrar x ${dst} ";;
            *.rpm) cmd="rpm2cpio > ${dst} | cpio --quiet -i --make-directories ";;
            *.zip) cmd="unzip -d ${dst} ";;
            *.z) cmd="uncompress ${dst} ";;
            *.7z) cmd="7z x ${dst} ";;
            *) echo "${FUNCNAME[0]}: ${src} cannot be extracted via decrunch"; return 1;;
		esac
		try pv ${src} | ${cmd}
		return $?
	else
		echo "${FUNCNAME[0]}: ${src} is not a valid file"
		return 1
	fi
}

wait_umount()
{
	test $# -gt 0 || { echo "${FUNCNAME[0]}: No params given"; return 1; }
	while $(mountpoint -q ${1}); do
		echo "Waiting for ${1} to unmount..."
		sleep 0.5
	done
}

cleanup()
{
	test $# -gt 0 || { echo "${FUNCNAME[0]}: No params given"; return 1; }
	local cmd_ix=${#clean_cmds[*]}
	clean_cmds[$cmd_ix]=$@
}

proceed_cleanup()
{
	local cmd_count=${#clean_cmds[*]}
	if [ ${cmd_count} -gt 0 ]; then
		execution_premission "Execute cleanup?" || return 1
		for cmd_ix in ${!clean_cmds[*]}
		do
			echo "${clean_cmds[cmd_count-cmd_ix-1]}"
			${clean_cmds[cmd_count-cmd_ix-1]}
		done
		sync
	fi
}

prompt_select(){
	local exitcode
	options+=" exit"
	#echo ${options[@]} ${!cmds[@]} ${cmds[@]}
	echo -e "\n$@\n"
	select i in ${options}
	do
		[ -n "${i}" ] && { selected="${i}"; break; }
	done
	case ${selected} in
		"skip"|"") exitcode=1;;
		"exit") die "Exiting...";;
		*) exitcode=0;;
	esac
	return $exitcode
}

prompt_new_dir(){
	read -p "Enter name of new directory " new_dir
	try "mkdir -p ${@}/${new_dir}" && { echo ${@}/${new_dir}; return 0; } || return 1
}

save_var(){
	[ $# -gt 1 ] || { echo "Two parameters expected!"; return 1; }
	[ -f "${2}" ] && { echo "${1}="${!1} >> "${2}"; return 0; } || { echo "${2} is not valid file!"; return 1; }
}

check_dir()
{
	if ! [ -d "${1}" ]; then
		if [ -z "${2}" ]; then
			echo "Directory ${1} doesn't exist."
			return 0
		else
			#echo "${2}" 1>&2
			return 1
		fi
	fi
}

is_mounted()
{
	test $# -gt 0 || { echo "${FUNCNAME[0]}: No params given"; return 1; }
	if cat /proc/mounts | grep -q "${1}"; then return 0; else return 1; fi
}

die()
{
	test $# -gt 0 && echo "$(basename ${PROGIMG}): $@"
	proceed_cleanup
	IFS=$XIFS
	exit 0
}

try()
{
	test $# -gt 0 || { echo "${FUNCNAME[0]}: No params given"; return 1; }
	printf "\n$@"
	$@ || printf "\n$@ exit with error code $?"
	return $?
}

freespace()
{
	test -n "${1}" || { echo "${FUNCNAME[0]}: No params given"; return 1; }
	echo $(df -m -P ${1} | grep " ${1}$" | tail -n 1 | awk '{print $4}')
	return $?
}
#!/bin/bash
# ppa-tool
# Eric J.

main ()
{
	shellcheck
	argcheck "$@"
	return 0
}

rootcheck()
{
	if [ "$EUID" -ne 0 ]; then
	echo -e "\e[31mError:\e[39m Run as root."
	echo -e "\e[32msudo "$0"\e[39m"
	exit
	fi
}

argcheck()
{
	case "$1" in
		-V|--version) version; exit;;
		-l| --list) listppas; exit;;
		-la| --listall) listallppas; exit;;
		-r|--remove) removeppa; exit;;
		-i|--installed) installedpackages; exit;;
		-a|--allpackages) allpackages; exit;;
		*) help; exit;;
	esac
}

help()
{
	echo "ppa-tool for ubuntu and debian based OS"
	echo "List ppas, all packages, installed packages from ppa, and remove ppas using ppa-purge"
	echo "ppa-tool [option]"
	echo "-l, --list		list active ppas"
	echo "-la, --listall		list all ppas"
	echo "-r, --remove		list ppas and remove one"
	echo "-i, --installed		list installed packages from ppa"
	echo "-a, --allpackages	list all packages from ppa"
	echo "-V, --version		show version information"
}

getppas()
{
	unset ppalist
	unset ppalistfiles
	readarray -t < <(grep -h "^[[:space:]]*deb " /etc/apt/sources.list.d/*.list | sed -e "s/^[[:space:]]*deb //") ppalist
	readarray -t < <(grep "^[[:space:]]*deb " /etc/apt/sources.list.d/*.list | cut -d":" -f1) ppalistfiles && return 0
}

getallppas()
{
	unset ppalistinactive
	unset ppalistfilesinactive
	readarray -t < <(grep -h "^[[:space:]]*#.*deb " /etc/apt/sources.list.d/*.list | sed -e "s/^[[:space:]]*#.*deb //") ppalistinactive
	readarray -t < <(grep "^[[:space:]]*#.*deb " /etc/apt/sources.list.d/*.list | cut -d":" -f1) ppalistfilesinactive && return 0
}

listppas()
{
	getppas || (echo "Something went wrong in /etc/apt/sources.list.d/*.list"; exit)

	echo -e "Currently \e[32mactive\e[39m ppas"
	for i in "${!ppalist[@]}"; do
	echo -e "\e[33m[$(($i + 1))]\e[39m ${ppalist[${i}]}"
	done
}

listallppas()
{
	getppas || (echo "Something went wrong in /etc/apt/sources.list.d/*.list"; exit)
	echo -e "Currently \e[32mactive\e[39m ppas"
	unset i
	for i in "${!ppalist[@]}"; do
	echo -e "\e[33m[$(($i + 1))]\e[39m ${ppalist[${i}]}"
	done
	getallppas || (echo "Something went wrong in /etc/apt/sources.list.d/*.list"; exit)
	unset i
		echo -e "Currently \e[31minactive\e[39m ppas"
	for i in "${!ppalistinactive[@]}"; do
	echo -e "\e[31m[$(($i + 1))]\e[39m ${ppalistinactive[${i}]}"
	echo "file location ${ppalistfilesinactive[${i}]}"
	done
	
	echo "Warning: ppa must be active before removing, edit the respective files and remove the comment "\(#\)" at the beginning to make a ppa active"
}

removeppa()
{
	rootcheck
	listppas || (echo -e "\e[31mError:\e[39m Something went wrong listing the ppas"; exit)
	unset ppanum
	read -r -p "Enter the ppa number to remove (q to quit): " ppanum
	if [ "$ppanum" == "q" ] || [ "$ppanum" == "quit" ]; then
		exit;
	fi
	if [[ -n ${ppanum//[0-9]/} ]]; then
		echo -e "\e[31mError:\e[39m ppa number is invalid"
		removeppa
	fi
	if [ "$ppanum" -gt "${#ppalist[@]}" ] || [ "$ppanum" -eq 0 ]; then
		echo -e "\e[31mError:\e[39m ppa number is invalid"
		removeppa
	else
		echo -e "Removing ppa ${ppalist[$(($ppanum - 1 ))]}"
		contq || removeppa
	fi
	ppapurgeinstalled
	makelist
	ppa-purge -p "${ppaname}" -o "${ppaowner}" -s "${ppahost}"
	echo -n "Disabling"
	sed -i 's/^[[:space:]]*deb/#deb/' "${ppalistfiles[$(($ppanum - 1))]}" && echo " ppa successful"
	exit
}

makelist()
{
	ppahttp=$(echo ${ppalist[$((ppanum - 1))]} | grep -o "http.*")
	ppanohttp=${ppahttp/http:\/\//}
	ppawunderscore=${ppanohttp//\//_}
	ppahost1=$(echo ${ppawunderscore} | cut -d" " -f1)
	ppahost2=${ppahost1%_}
	ppahost=${ppahost2}_dists
	ppaowner=$(echo ${ppawunderscore} | cut -d" " -f2)
	ppaname=$(echo ${ppawunderscore} | cut -d" " -f3)
	ppalistfile="/var/lib/apt/lists/${ppahost}_${ppaowner}_${ppaname}_*_Packages"
	unset i	
	for  i in $ppalistfile; do
		if [ ! -f "$i" ]; then
			echo -e "\e[31mError:\e[39m ppa list file doesn't exist, try \e[32mapt-get update\e[39m first"
			exit
		fi
	done
}

contq() 
{
	conta=""
	read -r -p "Continue? [y/n]: " cont
	conta=$(echo $cont | tr [A-Z] [a-z])
	if [ "$conta" == "y" ] || [ "$conta" == "yes" ]; then
		return 0;
	else
		return 1;
	fi
}

ppapurgeinstalled()
{
	command -v ppa-purge >/dev/null 2>&1 || (echo -e "\e[31mError:\e[39m ppa-purge not installed, install and re-run the script"; exit)
}

allpackages()
{
	listppas || (echo -e "\e[31mError:\e[39m Something went wrong listing the ppas"; exit)
	unset ppanum
	read -r -p "Enter the ppa number to show all packages available (q to quit): " ppanum
	if [ "$ppanum" == "q" ] || [ "$ppanum" == "quit" ]; then
		exit;
	fi	
	if [[ -n ${ppanum//[0-9]/} ]]; then
		echo -e "\e[31mError:\e[39m ppa number is invalid"
		allpackages
	fi	
	if [ "$ppanum" -gt "${#ppalist[@]}" ] || [ "$ppanum" -eq 0 ]; then
		echo -e "\e[31mError:\e[39m ppa number is invalid"
		allpackages
	else
		echo "Showing packages of ppa ${ppalist[$(($ppanum - 1 ))]}"
	fi
	makelist
	
	for i in $ppalistfile; do
		if [ -e $i ]; then
			grep "^Package: \|^Version: " $i;
		fi
	done

	exit
}

installedpackages()
{
	listppas || (echo -e "\e[31mError:\e[39m Something went wrong listing the ppas"; exit)
	unset ppanum
	read -r -p "Enter the ppa number to show installed packages (q to quit): " ppanum
	if [ "$ppanum" == "q" ] || [ "$ppanum" == "quit" ]; then
		exit;
	fi	
	if [[ -n ${ppanum//[0-9]/} ]]; then
		echo -e "\e[31mError:\e[39m ppa number is invalid"
		allpackages
	fi	
	if [ "$ppanum" -gt "${#ppalist[@]}" ] || [ "$ppanum" -eq 0 ]; then
		echo -e "\e[31mError:\e[39m ppa number is invalid"
		allpackages
	else
		echo "Showing installed packages of ppa ${ppalist[$(($ppanum - 1 ))]}"
	fi
	makelist
	
	ppaendremoved=${ppanohttp/\/ / }
	ppareversed=$(echo $ppaendremoved | rev)
	pparevwunderscore=${ppareversed/ /\/}
	ppaaptcache=$(echo $pparevwunderscore | rev)
	unset i
	for i in $ppalistfile; do
		if [ -e $i ]; then
			grep "^Package: " $i | cut -d " " -f2 | sort
		fi
	done | while IFS='' read -r possiblepkg; do
			installedversion=$(apt-cache policy $possiblepkg | fgrep "Installed:" | awk '{ print $2 }')
			installedsource=$(apt-cache policy $possiblepkg | fgrep -A1 " *** $installedversion" | tail -n 1)
			if echo $installedsource | grep -q "$ppaaptcache"; then
				echo "* $possiblepkg version $installedversion"
				unset installedversion
				unset installedsource
			fi
		done
	exit
}

version()
{
	echo -e "\e[32mppa-tool\e[39m"
	echo -e "Eric J"
	echo -e "https://github.com/ericj112/ppa-tool"
}

shellcheck()
{
	pid=$(echo $$)
	ps -auxq ${pid} | grep "bash" > /dev/null 2>&1 || (echo "\e[31mError:\e[39m Use bash shell, exiting.."; exit)
}

main "$@"

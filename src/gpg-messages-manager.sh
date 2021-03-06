#!/bin/bash
#    ____             ____   ____
#   / ___|_ __  _   _|  _ \ / ___|
#  | |  _| '_ \| | | | |_) | |  _
#  | |_| | | | | |_| |  __/| |_| |
#   \____|_| |_|\__,_|_|    \____| Messages Manager
#
# Interactive application for encrypting
# and decrypting PGP messages efficiently.
# Dependencies : GnuPG, FZF

# Defining home directory variable and default text editor

gpgDir=$HOME/Documents/pgp
editor=vim
fzf="fzf --height 30% --layout=reverse --border"

# Text format
bs=$(tput bold)
be=$(tput sgr0)

# Text color
red='\033[0;31m'
green='\033[0;32m'
end='\033[0m'

# The function checkDependencies() allows us to verify if the user has installed the required software in order to use this script 


function checkDependencies() {
	dependencies=( gpg fzf $editor )
	ready=0

	for i in "${dependencies[@]}"; do
		which $i > /dev/null

		if [ $? -ne 0 ]; then
			ready=1
			break
		fi
	done

	if [ $ready -eq 0 ]; then
		checkDirectories
	else
		exit 1
	fi
}


# The function checkDirectories() allows us to verify if the directories we need already exists or if we needto create them

function checkDirectories() {
 	cd $HOME

 	if [ ! -d Documents ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt,sig}

 	elif [ ! -d Documents/pgp ]; then
 		mkdir -p Documents/pgp/{asc,pub,txt,sig}

 	elif [ ! -d Documents/pgp/asc ]; then
 			mkdir Documents/pgp/asc

 	elif [ ! -d Documents/pgp/pub ]; then
 			mkdir Documents/pgp/pub

 	elif [ ! -d Documents/pgp/txt ]; then
 			mkdir Documents/pgp/txt
	elif [ ! -d Documents/pgp/sig ]; then
		mkdir Documents/pgp/sig

 	else
 		echo "All OK."
 	fi

	checkAddr
}

# The function checkAddr() is not a function that the user is going to see it  allows us to verify if the file we need already exist if it doesn't exist we create it 

function checkAddr() {
	cd $gpgDir
	if [ -f txt/adr.txt ]; then
		if [ $(du txt/adr.txt) -le 0 ]; then
			setAddr
		else
			showMenu
		fi
	else
		setAddr
	fi
}

# The function setAddr() follow the checkAddr() function, once the file is created we ask the user to writehis adress in adr.txt

function setAddr() {
	cd $gpgDir
	echo -e "You firstly need to specify your address."
	read -p "Press Enter to enter your address..." foo
	$editor txt/adr.txt
	checkAddr
}

# The function showMenu() allows us to bring to the user a simple presentation to all functionalities

function showMenu() {
	clear
	echo "${bs}Welcome to GnuPG !${be}"
	askOption
}

# The function askOption() allows to treat the user input in order to select wich funtion to call regardingthe user selection

function askOption() {

	options=(
		"Show keyring"
		"Generate a new key pair"
		"Import a public key"
		"Export a public key"
		"Remove a public key"
		"Encrypt your addresse"
		"Encrypt a message"
		"Decrypt a message"
		"Sign a file"
		"Verify a file"
		"Exit"
	)

	choice=$(for (( i=0; i<${#options[*]}; i++ )); do
		echo "[${i}] ${options[${i}]}"
	done |
	$fzf |
	cut -d ' ' -f1 |
	grep -oE '([0-9])'
	)

	case $choice in
		0)
			showKeys "i";;
		1)
			genKey;;
		2)
			addPubKey;;
		3)
			exportPubKey;;
		4)
			delPubKey;;
		5)
			encryptMsg "adr";;
		6)
			encryptMsg;;
		7)
			decryptMsg;;
		8)
			signFile;;
		9)
			verifyFile;;
	esac
	clear
}

# The function showKeys() allows us to show every public keys the user has added to his keyring

function showKeys() {
	if [ "$1" == "i" ]; then
		echo
	fi

	gpg --list-keys |
		grep -E '^uid' |
		sed 's/^.\+\] //' |
		sed 's/>//' |
		sed 's/ </;/' |
		cut -d ';' -f 1- --output-delimiter=$'\t\t\t'

	if [ "$1" == "i" ]; then
		toMenu
	fi
}

# The function toMenu() is not a function that the user is going to see it's just use at the end of almost every other function in order to go back to the menu once the user has finished using a functionality

function toMenu() {
	echo; read -p "Press Enter to continue..." foo
	showMenu
}

# The function selectKey() is not a function that the user is going to see it's just the way that the user isgoing to select a public key

function selectKey() {
	showKeys | $fzf | cut -f4 -d $'\t'
}

# The function genKey() allows the user to generate a key pair (the private key and the public key)

function genKey() {

	gpgVersion=$(gpg --version | sed 1q | cut -d ' ' -f3)

	if [ $(echo -e "2.2.17\n${gpgVersion}" | sort -V | head -n1) == "2.2.17" ]; then

		# GPG version is greather than 2.2.17
		gpg --full-generate-key
	else

		# GPG version is lower than 2.2.17
		gpg --gen-key
	fi

	toMenu
}

# The function addPubKey() allows the user to add a public key to his keyring if he register a public key 

function addPubKey() {

	cd $gpgDir
	echo "Please select a public key to import : "

	public=$(
		ls pub/ |
		head |
		$fzf
	)

	if [ ! -z $public ]; then
		gpg --batch --yes --import pub/$public
		if [ $? -eq 0 ]; then
			echo -e "${green}\nPublic key $public added !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log.${end}"
		fi
	fi

	toMenu
}

# The function delPublicKey() allows the user to delete a public key from his keyring

function delPubKey() {
	echo "Please select a public key to delete : "
	public=$(selectKey)
	gpg --batch --yes --delete-key $public

	if [ ! -z $public ]; then
		if [ $? -eq 0 ]; then
			echo -e "${green}Public key $public deleted !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
		fi
	fi

	toMenu
}

# The function encryptMsg() use the gpg functionality to encrypt a message from the user input or by a parameter encrypt the adr.txt file

function encryptMsg() {
	cd $gpgDir
	echo "Please select a recipient : "
	recipient=$(selectKey)

	if [ ! -z $recipient ]; then

		if [ "$1" == "adr" ]; then
			gpg --trust-model always --armor --encrypt --recipient $recipient txt/adr.txt

			if [ $? -eq 0 ]; then
				recipientFormat=$(echo -n 'adr_for_'; echo $recipient | sed 's/@.\+$//')
				mv txt/adr.txt.asc asc/$recipientFormat.asc

				echo -e "\n${green}Address encrypted for ${bs}${recipient}${be}\nto $gpgDir/asc/${bs}$recipientFormat.asc${be} !${end}"
			else
				echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
			fi

		else
			$editor txt/tmp.txt
			gpg --trust-model always --armor --encrypt --recipient $recipient txt/tmp.txt

			if [ $? -eq 0 ]; then
				recipientFormat=$(echo -n 'msg_for_'; echo -n $recipient | sed 's/@.\+$/_/'; date +%Y%m%d_%H%M%S)
				mv txt/tmp.txt.asc asc/$recipientFormat.asc
				rm txt/tmp.txt

				echo -e "\n${green}Message encrypted for ${bs}${recipient}${be}\nto $gpgDir/asc/${bs}$recipientFormat.asc${be} !${end}"

				# Would you like to sign it ?
			else
				echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
			fi
		fi

	fi

	echo 'RELOADAGENT' | gpg-connect-agent
	toMenu
}


# The function decryptMsg() allows the user to decrypt a message from an external source thank to the public key of this external user

function decryptMsg() {
	cd $gpgDir
	messages=$(ls asc/ | grep '^msg' | head -n99)
	echo "Please select a message to decrypt : "
	toDecryptMsg=$(echo -e "$messages" | $fzf)

	if [ ! -z $toDecryptMsg ]; then

		gpg --output txt/$toDecryptMsg.txt --decrypt asc/$toDecryptMsg

		if [ $? -eq 0 ]; then
			echo -e "\n${green}Message successfully decrypted to $gpgDir/txt/${bs}$toDecryptMsg.txt${be} !${end}"
			echo -e "\nWould you like to see the message now ?\n[Y]es / [N]o\n"
			read -p ">>> " answerMsg

			while [[ ! $answerMsg == "Y" && ! $answerMsg == "y" && ! $answerMsg == "N" && ! $answerMsg == "n" ]]; do
				echo -e "\nPlease choose between Y or N !"
				read -p ">>> " answerMsg
			done

			if [[ $answerMsg == "Y" || $answerMsg == "y" ]]; then
				$editor txt/$toDecryptMsg.txt
			fi
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log..${end}"
		fi

	fi

	echo 'RELOADAGENT' | gpg-connect-agent
	toMenu
}

# The function exportPubKey() allows the user to export into an asc file his public key

function exportPubKey() {
	cd $gpgDir
	echo -e "\nPlease select a public key to export : "
	public=$(selectKey)

	if [ ! -z $public ]; then

		pubFormat=$(echo -n $public | sed 's/@.\+$/_/' | sed 's/\./_/g'; echo 'pub.asc')
		gpg -ao pub/${pubFormat} --export ${public}

		if [ $? -eq 0 ]; then
			echo -e "\n${green}Public key successfully exported to $gpgDir/pub/${bs}${pubFormat}${be} !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log.${end}"
		fi

	fi

	echo RELOADAGENT | gpg-connect-agent
	toMenu
}

# The function signFile() allow the user to sign a file in order to make it reliable

function signFile() {
	cd $gpgDir
	echo -e "\nPlease select a file to sign : "
	file=$(ls asc/ txt/ | sed '/.*\/:/d' | sed '/^$/d' | head -n99 | $fzf)

	if [ ! -z $file ]; then

		gpg --armor --output sig/${file}.sig --detach-sig $(find | grep $file | tail -n1)

		if [ $? -eq 0 ]; then
			echo -e "\n${green}File successfully signed to $gpgDir/sig/${bs}${file}.sig${be} !${end}"
		else
			echo -e "\n${red}Warning: An error occured. Please refer to the gpg error log.${end}"
		fi

	fi

	echo RELOADAGENT | gpg-connect-agent
	toMenu
}

# The function verifyFile() allows the user to verify the reliability of a file

function verifyFile() {
	cd $gpgDir
	echo -e "\nPlease select a file to verify : "
	signature=$(ls sig/ | $fzf)

	if [ ! -z $signature ]; then

		fileSign=$(find asc/ txt/ | grep $(echo $signature | sed 's/\.sig$//'))
		gpg --verify sig/${signature} ${fileSign}

		if [ $? -ne 0 ]; then
			exit 1
		fi

	fi

	echo RELOADAGENT | gpg-connect-agent
	toMenu
}

checkDependencies

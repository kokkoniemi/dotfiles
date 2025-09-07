#!/bin/bash

bashrc_path="$HOME/.bashrc"
if [ -e "$bashrc_path" ]; then
	echo "'$bashrc_path' exists..."
else
	touch "$bashrc_path"
	echo "Created '$bashrc_path'..."
fi

prompt_cmd_str="
#Source git prompt
. /usr/share/git-core/contrib/completion/git-prompt.sh

# PS1

update_PS1 () {
	PS1=\"\033]0;\$USER@\$HOSTNAME\007\W\[\e[91m\]\$(__git_ps1)\[\e[00m\]$ \"
}

update_PS1
PROMPT_COMMAND=update_PS1
"

if ! grep -q "PROMPT_COMMAND=.*" "$bashrc_path"; then
	echo "$prompt_cmd_str" >> "$bashrc_path"	
	echo "Following written to $bashrc_path:"
	echo "$prompt_cmd_str"
else
	echo "PROMPT_COMMAND already set"
fi


time="%(?.%{$fg[green]%}.%{$fg[red]%})%*%{$reset_color%}"

PROMPT="${time} %{$fg[cyan]%}%~%{$reset_color%}"
PROMPT+='$(git_prompt_info) > '

ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg[white]%}("
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[white]%})%{$reset_color%}"

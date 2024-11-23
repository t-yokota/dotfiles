#!/usr/bin/env bash

DOTPATH=~/dotfiles
OH_MY_ZSH_THEMES=~/.oh-my-zsh/themes

cd "$DOTPATH" || { echo "Error: Could not cd to $DOTPATH"; exit 1; }

echo "Creating symbolic links for .dotfiles in $DOTPATH"
for f in .??*; do
    [ "$f" = ".git" ] && continue
    ln -snfv "$DOTPATH/$f" "$HOME/$f"
done

if [ -d "$OH_MY_ZSH_THEMES" ]; then
    echo "Creating symbolic links for .zsh-theme files in $OH_MY_ZSH_THEMES"
    for theme in "$DOTPATH"/*.zsh-theme; do
        ln -snfv "$theme" "$OH_MY_ZSH_THEMES/$(basename "$theme")"
    done
else
    echo "Directory $OH_MY_ZSH_THEMES does not exist. Skipping theme linking."
fi

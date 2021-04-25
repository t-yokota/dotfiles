#!/usr/bin/env bash

DOTPATH=~/dotfiles
cd $DOTPATH

for f in .??*
do
    [ "$f" = ".git" ] && continue
    ln -snfv $DOTPATH/$f $HOME/$f
done

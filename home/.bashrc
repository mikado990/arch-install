#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ -f ~/.config/shell/aliasrc ]] && . ~/.config/shell/aliasrc

PS1='[\u@\h \W]\$ '

#!/usr/bin/env bash

# Functions
update_repo() {
  cd "$(dirname "${BASH_SOURCE}")"
  git pull origin master
}

install_repo() {
    cd "$(dirname "${BASH_SOURCE}")"
  rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" \
    --exclude "README.md" --exclude "LICENSE" \
    -av --no-perms . ~
}

resource() {
  source ~/.profile
}

doIt() {
  update_repo
  install_repo
  resource
}

# MAIN
if [ "$1" == "--force" -o "$1" == "-f" ]; then
    doIt
else
    read -p "Updating osx-dotfiles may overwrite existing customized configuration. Are you sure to proceed? (y/n) " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        doIt
    fi
fi

unset update_repo
unset install_repo
unset resource
unset doIt

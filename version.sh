#!/bin/sh

# FUNCTIONS
yellow(){
        printf "\033[1;33m$@\033[m"
}

red(){
        printf "\033[1;31m$@\033[m"
}

info(){
  echo "$(yellow '::') $@"
}

warn(){
  echo $(yellow ":: $@")
}

error(){
  echo $(red ":: $@")
}

bump(){
  bump_new_version $1
  echo
  push_changes $1
  echo "$1" > $VERSION_FILE
  info "Finished"
}

bump_new_version(){
  if [ ! "$#" = "1" ]; then
    $SCRIPT; exit 1
  fi

  warn "This script will try to update files to a new version '$1'."
  warn "Please, ensure that you have no unstaged or untracked files on this repository before proceed."
  info "Press [ENTER] to continue. [Ctrl+C] to abort."
  read should_continue

  git submodule foreach $SCRIPT bump-submodule-version $1 || exit_due_to_failure
  sed -i -e "s/${VERSION}/$1/" pom.yml
}

bump_submodule_version(){
  ensure_submodule_is_at_last_version
  update_pom_files $1
}

ensure_submodule_is_at_last_version(){
  info "Updating submodule..."
  git checkout master --quiet || exit 1
  git pull --quiet || exit 1
}

update_pom_files(){
  info "Updating pom.yml files with new version..."
  pom_files=`find . -name 'pom.yml'`
  sed -i -e "s/${VERSION}/$1/" ${pom_files}
}

push_changes(){
  if [ ! "$#" = "1" ]; then
    $SCRIPT; exit 1
  fi

  info "Pull changes on submodules to their respectives repositories?"
  info "Type 'YES' to confirm. Any other value will skip this step."
  read should_continue

  if [ "${should_continue}" = "YES" ]; then
    git submodule foreach $SCRIPT push-submodule-changes $1 || exit_due_to_failure
    push_submodule_changes $1
  fi
}

push_submodule_changes(){
  git commit -am "Version $1" --quiet || exit 1
  git push --quiet || exit 1
}

clean(){
  warn "By cleaning up the repository, any untracked or unstaged file will be ignored."
  info "Press [ENTER] to continue. [Ctrl+C] to abort."
  read should_continue

  git submodule foreach $SCRIPT clean-submodule-changes || exit_due_to_failure
  git checkout -- $VERSION_FILE
}

clean_up_submodule(){
  git reset --quiet HEAD . || exit 1
  git checkout --quiet -- . || exit 1
}

exit_due_to_failure(){
  warn "WARNING: Failed to bump version and this script wasn't able to recover the previous state of the source code."
  warn "You rather manually check your source code and undo the changes made by this script"
  echo && exit 2
}

# VARIABLES
CWD=`pwd`
SCRIPT=`realpath $0`
VERSION_FILE="`dirname $0`/version.dat"
VERSION=`cat ${VERSION_FILE}`

# MAIN
case "$1" in
  "bump-submodule-version") bump_submodule_version $2 ;;
  "push-submodule-changes") push_submodule_changes $2 ;;
  "clean-submodule-changes" ) clean_up_submodule ;;
  "bump") bump $2 ;;
  "clean") clean ;;
  "apply") push_changes $VERSION ;;
  *) echo "Usage: $0 <apply|bump|clean> <version>"; exit 1 ;;
esac


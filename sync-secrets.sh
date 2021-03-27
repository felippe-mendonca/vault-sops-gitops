#!/bin/bash

set -eo pipefail

# ------------------------------ FUNCTIONS ------------------------------------

# $1 - Operation
# $2 - Secret Path

function log_operation() {
  printf "\n[%s] [secret] %s\n" $1 $2
}

function vault_put() {
  log_operation $1 $2
  if [ "${DRY_RUN}" == "false" ]; then
    $INSPECT_FILE_CMD secrets/$2.json | vault kv put $2 -
  fi
}

function vault_delete() {
  log_operation $1 $2
  if [ "${DRY_RUN}" == "false" ]; then
    vault kv metadata delete $2
  fi
}
 
# ------------------------------- OPTIONS -------------------------------------

DRY_RUN=${DRY_RUN:=true} # default to `true`
DRY_RUN=${DRY_RUN,,}     # lowercase
case $DRY_RUN in
  'false')
  ;;
  'true')
    printf "[.] Running in dry-run mode\n"
  ;;
  *)
    printf "[X] Invalid DRY_RUN option. Must be 'true' or 'false'. Default is 'true'"
    exit 1
  ;;
esac

USE_SOPS=${USE_SOPS:=true} # default to `true` 
USE_SOPS=${USE_SOPS,,}     # lowercase
case $USE_SOPS in
  'false')
    INSPECT_FILE_CMD="cat"
  ;;
  'true')
    INSPECT_FILE_CMD="sops -d"
    printf "[.] Using SOPS to decrypt files\n"
  ;;
  *)
    printf "[X] Invalid USE_SOPS option. Must be 'true' or 'false'. Default is 'true'"
    exit 1
  ;;
esac

RUN_MODE=${RUN_MODE:=git} # defaults to `git`
RUN_MODE=${RUN_MODE,,}    # lowercase
case $RUN_MODE in
  'git')
    if [ -z "$CI_COMMIT_SHA" ]; then
      CI_COMMIT_SHA=`git rev-parse --verify HEAD`
    fi
    MODIFIED_FILES=`git diff-tree --no-commit-id --name-status -r $CI_COMMIT_SHA`
  ;;
  'all')
    MODIFIED_FILES=`find secrets/ -type f -name '*.json' | sed -nE 's/(.*)/A\t\1/p'`
  ;;
  *)
    printf "[X] Invalid RUN_MODE. Must be 'git' or 'all'. Default is 'git'"
    exit 1
  ;;
esac

# ------------------------------- MAIN ----------------------------------------
  
printf "%s\n" "$MODIFIED_FILES" | while read change; do

  OPERATION=`printf "$change" | sed -nE 's/^(\w)\s+secrets\/.*\.json$/\1/p'`
  SECRET_PATH=`printf "$change" | sed -nE 's/^[AMD]\s+secrets\/(.*)\.json$/\1/p'`

  case $OPERATION in 
    'A'|'M')
      vault_put $OPERATION $SECRET_PATH
    ;;
    'D')
      vault_delete $OPERATION $SECRET_PATH
    ;;
  esac

done


#!/bin/bash

set -eo pipefail

SECRET_ENGINE=${SECRET_ENGINE:=kv}      # default to `kv` 
OUTPUT_FOLDER=${OUTPUT_FOLDER:=secrets} # default to `secrets` 

function dump_secret() {

  local SECRET_PATH=$1
  local levels=""
  IFS='/' read -ra levels <<<  $SECRET_PATH
  filename=`printf "%s.json" "${levels[-1]}"`
  unset levels[-1]
  secret_path=`printf "%s/" "${levels[@]}"`

  printf "[.] %s %s\n" "$secret_path" "$filename"

  local output_folder=$OUTPUT_FOLDER/$secret_path
  local output_filename=$output_folder/$filename
  mkdir -p $output_folder

  bash -c "vault kv get --address $VAULT_ADDR -format=json $SECRET_PATH | jq .data.data -M | sops --input-type json -e /dev/stdin 2>/dev/null > $output_filename" &
  disown -a
}

function walk_secrets_path() {

  local SECRET_PATH=$1
  local SECRETS=`vault kv list --address $VAULT_ADDR $SECRET_PATH | tail +3`

  printf "%s\n" "$SECRETS" | while read secret; do
    local secret_path=`printf "%s/%s" $SECRET_PATH $secret | sed -e 's/\/\//\//g'`
    if [[ "$secret" =~ ^.*/$ ]]; then
      walk_secrets_path $secret_path
    else
      dump_secret $secret_path
    fi
  done

}


walk_secrets_path $SECRET_ENGINE


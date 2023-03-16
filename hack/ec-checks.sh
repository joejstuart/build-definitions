#!/bin/bash

set -e -o pipefail

generated_pipelines_dir=$(mktemp -d -p "$WORKDIR" pipelines.XXXXXXXX)
WORKDIR=$(mktemp -d --suffix "-$(basename "${BASH_SOURCE[0]}" .sh)")

function build_container_name {
    cat "${generated_pipelines_dir}/${1}" | yq '.spec.tasks[] | select(.name == "build-container") .taskRef.name'
}

oc kustomize --output "$generated_pipelines_dir" pipelines/
declare -A task_with_versions=()
for f in `ls $generated_pipelines_dir`; 
do
  # find all tasks that are named "build-container" in each pipeline
  name=`build_container_name $f`
  if [[ -z $name ]]; then
    continue
  fi

  # the same build task can be used for multiple pipelines
  # so find all the task files while filtering duplicates
  for task_file in `find task/"$name"/*/*.yaml`
  do
    task_with_versions["$task_file"]=$name
  done

done

with_commas=`printf '%s,' "${!task_with_versions[@]}"`
/home/jstuart/ec-cli/dist/ec validate pipeline --pipeline-file $with_commas \
    --policy git::https://github.com/hacbs-contract/ec-policies//policy/pipeline \
    --policy git::https://github.com/hacbs-contract/ec-policies//policy/lib \
	  --data git::https://github.com/hacbs-contract/ec-policies//data


#!/usr/local/bin/bash

set -e -o pipefail

generated_pipelines_dir=$(mktemp -d -p "$WORKDIR" pipelines.XXXXXXXX)
WORKDIR=$(mktemp -d --suffix "-$(basename "${BASH_SOURCE[0]}" .sh)")

function build_container_name {
    cat "${generated_pipelines_dir}/${1}" | yq '.spec.tasks[] | select(.name == "build-container") .taskRef.name'
}

kubectl kustomize --output "$generated_pipelines_dir" pipelines/
declare -A task_with_versions=()
tmpdir=`mktemp -d`
for f in `ls $generated_pipelines_dir`; 
do
  # find all tasks that are named "build-container" in each pipeline
  name=`build_container_name $f`
  if [[ -z $name ]]; then
    continue
  fi

  for task_file in `find task/"$name"/*/*.yaml`
  do
      cp $task_file $tmpdir
      task_with_versions["$task_file"]=$name
  done
done

/Users/jstuart/Documents/repos/ec-cli/dist/ec validate definition --file $tmpdir \
--policy oci::quay.io/jstuart/ec-policies:latest --namespace policy.build_task.labels 

rm -rf $tmpdir

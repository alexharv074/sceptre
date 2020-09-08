#!/usr/bin/env bash

CWD=$(pwd)
[ -z "$CONFIG" ] && CONFIG=~/.aws/config

usage() {
  cat <<EOF
Usage: [AWS_PROFILE=AWS_PROFILE] bash $0 [-hkr] [-p AWS_PROFILE] [-c CONFIG_DIR] [COMMAND]
    AWS_PROFILE       The AWS profile to use
     -f               Full mode. Do not mount ~/.aws/config. Signals oktashell
     -h               Show this help
     -k               Kube mode. Also mount ~/.kube:/root/.kube
     -p AWS_PROFILE   Alternative way to set the AWS profile
     -c CONFIG_DIR    Configuration directory override
    COMMAND           Command to run in pass-through mode (non-interactive)
EOF
  exit 1
}

is_mode() {
  grep -q ",$1," <<< "$mode"
}

set_mode() {
  mode=$(sed 's/no'"$1"'/'"$1"'/' <<< "$mode")
}

check_profile() {
  if grep -q "^data/" <<< "$AWS_PROFILE" ; then
    if [ -d "$AWS_PROFILE" ] ; then
      AWS_PROFILE=$(basename "$AWS_PROFILE")
    else
      echo "Invalid profile - $AWS_PROFILE"
      usage
    fi
  fi

  is_mode 'full' && return

  if ! grep -q "$AWS_PROFILE" "$CONFIG" ; then
    echo "AWS_PROFILE $AWS_PROFILE not found in $CONFIG ..."
    usage
  fi
}

check_config_dir() {
  if ! is_mode 'profile' ; then
    echo "-c must be specified in conjunction with a profile"
    usage
  fi
}

set_args() {
  docker_image='kayosportsau/docker-ubuntu-aws-cli:latest'
  mode=',nofull,nokube,noprofile,noconfigdir,'

  while getopts "fhkp:c:" opt; do
    case "$opt" in
      h) usage ;;

      f) set_mode 'full' ;;
      k) set_mode 'kube' ;;

      p) AWS_PROFILE="$OPTARG" ;;
      c) CONFIG_DIR="$OPTARG" ;;

      *) usage ;;
    esac
  done
  shift $((OPTIND -1))

  if [ ! -z "$AWS_PROFILE" ] ; then
    set_mode 'profile'
    check_profile
  fi

  if [ ! -z "$CONFIG_DIR" ] ; then
    set_mode 'configdir'
    check_config_dir
  fi

  cmd="$@"
}

run_docker() {
  local docker_run docker_args
  
  docker_args=(
    -e AWS_DEFAULT_REGION='ap-southeast-2'
    -v ~/.ssh:/root/.ssh
    -v "$CWD":/src)

  if is_mode 'full' ; then
    docker_args+=(-e FULL_MODE='true')
  else
    docker_args+=(-v ~/.aws:/root/.aws)
  fi

  [ -z "$CONFIG_DIR" ] && \
    CONFIG_DIR="$CWD"/data/"$AWS_PROFILE"

  is_mode 'profile' && \
    docker_args+=(
      -v "$CONFIG_DIR":/env
      -e AWS_PROFILE="$AWS_PROFILE")

  is_mode 'kube' && \
    docker_args+=(-v ~/.kube:/root/.kube)

  docker_run=(docker run "${docker_args[@]}"
    -it --rm "$docker_image")

  [ ! -z "$cmd" ] && \
    docker_run+=(
      bash -c '"LC_ALL=C.UTF-8 LANG=C.UTF-8 $cmd"')

  eval "${docker_run[@]}"
}

main() {
  set_args "$@"
  run_docker
}

if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
  main "$@"
fi

# vim: set ft=sh:

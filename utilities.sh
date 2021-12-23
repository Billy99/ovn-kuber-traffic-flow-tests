#!/bin/bash

test_for_kubectl() {
  kubectl version  &>/dev/null

  if [ $? != 0 ]; then
    oc version  &>/dev/null
    if [ $? != 0 ]; then
      echo
      echo "Either \`kubectl\` or \`oc\` must be installed. Exiting ..."
      echo
      exit 1
    fi

    alias kubectl="oc"
  fi
}

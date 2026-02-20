#!/bin/bash
set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: $0 <env> (dev|prod|dr)"
  exit 1
fi

echo "=========================================="
echo " Destroying '$ENV' Environment"
echo "=========================================="

destroy_stack() {
  STACK=$1
  DIR="../stacks/$STACK/envs/$ENV"
  
  if [ -d "$DIR" ]; then
    echo "Destroying $STACK..."
    pushd "$DIR" > /dev/null
    terraform init
    terraform destroy -auto-approve
    popd > /dev/null
    echo "Done $STACK."
  else
    echo "Skipping $STACK (Directory not found: $DIR)"
  fi
}

# Reverse Dependency Order
destroy_stack "30-database"
destroy_stack "20-edge"
destroy_stack "10-net-sec"
destroy_stack "00-base-network"

echo "=========================================="
echo " Destruction Complete: $ENV"
echo "=========================================="

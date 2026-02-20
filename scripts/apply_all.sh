#!/bin/bash
set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: $0 <env> (dev|prod|dr)"
  exit 1
fi

echo "=========================================="
echo " Deploying '$ENV' Environment"
echo "=========================================="

apply_stack() {
  STACK=$1
  DIR="../stacks/$STACK/envs/$ENV"
  
  if [ -d "$DIR" ]; then
    echo "Processing $STACK..."
    pushd "$DIR" > /dev/null
    terraform init
    terraform apply -auto-approve
    popd > /dev/null
    echo "Done $STACK."
  else
    echo "Skipping $STACK (Directory not found: $DIR)"
  fi
}

# Dependency Order
apply_stack "00-base-network"
apply_stack "10-net-sec"
apply_stack "20-edge"
apply_stack "30-database"

echo "=========================================="
echo " Deployment Complete: $ENV"
echo "=========================================="

#!/usr/bin/env bash

###
# Author: Jakob Beckmann <jakob.beckmann@ipt.ch>
# Description:
#   Bootstrap the exercise environment for several users.
#
# Dependencies:
#   - kubectl
#   - helm (v3)
#
# Usage:
#   <script> [user-count]
#
#   [user-count] the number of users to initiate the environment for (defaults to 10).

set -euo pipefail
IFS=$'\n\t'

user_count="${1:-10}"

logdir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")

# check that bitnami Helm repo is added
set +e
helm repo add bitnami https://charts.bitnami.com/bitnami > "$logdir/helm-repo-add" 2>&1
set -e

for idx in $(seq 0 "$user_count"); do
  echo "[+] setting up user $idx..."
  kubectl create ns "user-$idx" > "$logdir/user-$idx-create-ns" 2>&1
  sleep 1s
  helm install -n "user-$idx" cache bitnami/redis-cluster \
    --set "persistence.size=1Gi" \
    --set "redis.resources.requests.cpu=20m" \
    --set "redis.resources.requests.memory=25Mi" \
    --set "metrics.enabled=true" \
    > "$logdir/user-$idx-install-redis" 2>&1
  helm install -n "user-$idx" sample-app part1/sample-app > "$logdir/user-$idx-install-app" 2>&1
done

echo "[+] done"


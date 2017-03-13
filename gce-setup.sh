#!/bin/bash
if [ $(uname) = Darwin ]; then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
else
  readlinkf(){ readlink -f "$1"; }
fi
DIND_ROOT="$(cd $(dirname "$(readlinkf "${BASH_SOURCE}")"); pwd)"
KUBE_DIND_GCE_PROJECT="${KUBE_DIND_GCE_PROJECT:-$(gcloud config list --format 'value(core.project)' 2>/dev/null)}"
# Based on instructions from k8s build/README.md
if [ -z "${KUBE_DIND_GCE_PROJECT:-}" ]; then
    echo >&2 "Please set KUBE_DIND_GCE_PROJECT or use 'gcloud config set project NAME'"
    return 1
fi

set -x
KUBE_DIND_VM=k8s-dind
export KUBE_RSYNC_PORT=8730
export APISERVER_PORT=8899
docker-machine create \
               --driver=google \
               --google-project=${KUBE_DIND_GCE_PROJECT} \
               --google-machine-image=ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20170307 \
               --google-zone=us-west1-a \
               --google-machine-type=n1-standard-8 \
               --google-disk-size=50 \
               --google-disk-type=pd-ssd \
               --engine-storage-driver=overlay2 \
               ${KUBE_DIND_VM}
eval $(docker-machine env ${KUBE_DIND_VM})
docker-machine ssh ${KUBE_DIND_VM} \
               -L ${KUBE_RSYNC_PORT}:localhost:${KUBE_RSYNC_PORT} \
               -L ${APISERVER_PORT}:localhost:${APISERVER_PORT} \
               -N&
time "${DIND_ROOT}"/dind-cluster.sh up
set +x

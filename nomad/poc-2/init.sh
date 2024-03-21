#/usr/bin/env bash
set -xeu -o pipefail

pwd
ls -lha

# this directory is persisted across job runs and can be used to persist state over time.
JOB_STATE_DIRECTORY="${STATE_DIRECTORY}/${NOMAD_JOB_ID}"
mkdir -p "${JOB_STATE_DIRECTORY}"
cd "${JOB_STATE_DIRECTORY}"

if [[ -d holochain/.git ]]; then
    cd holochain
    git status
    git remote set-url origin ''${GIT_URL}
    git fetch origin ''${GIT_BRANCH}
    git checkout -B ''${GIT_BRANCH} origin/''${GIT_BRANCH}
else
    rm -rf holochain
    git clone ''${GIT_URL} --depth 1 --single-branch --branch ''${GIT_BRANCH}
    cd holochain
fi

git clean -fd
git status

ls -lha

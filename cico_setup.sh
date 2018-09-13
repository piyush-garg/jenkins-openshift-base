#!/bin/bash
#
# Build script for CI builds on CentOS CI

set -ex

function get_hub_latest_release() {
  version=$(curl --silent "https://api.github.com/repos/github/hub/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E -e 's/.*"([^"]+)".*/\1/'  -e 's/^v//'
  )

  curl -s -L https://github.com/github/hub/releases/download/v${version}/hub-linux-amd64-${version}.tgz |\
      tar -v -x --strip-components=2 -f- -z -C /usr/local/bin hub-linux-amd64-${version}/bin/hub
}

function setup() {
    if [ -f jenkins-env.json ]; then
        eval "$(./env-toolkit load -f jenkins-env.json \
                FABRIC8_HUB_TOKEN \
                FABRIC8_DOCKERIO_CFG \
                ghprbActualCommit \
                ghprbPullId \
                GIT_COMMIT \
                BUILD_ID)"

        mkdir -p ${HOME}/.docker
        echo ${FABRIC8_DOCKERIO_CFG}|base64 --decode > ${HOME}/.docker/config.json
    fi

    get_hub_latest_release

    # We need to disable selinux for now, XXX
    /usr/sbin/setenforce 0 || :

    yum -y install docker make golang git
    service docker start

    echo 'CICO: Build environment created.'
}

function build_push_images() {
    if [[ $1 == "release" ]];then
        newVersion="v$(git rev-parse --short ${GIT_COMMIT})"
    else
        newVersion="PR-${ghprbPullId}-${BUILD_ID}"
    fi

    make build VERSION=2
    make build VERSION=slave-base

    docker tag openshift/jenkins-2-centos7:latest fabric8/jenkins-openshift-base:${newVersion}
    docker push fabric8/jenkins-openshift-base:${newVersion}

    if [[ $1 == "release" ]];then
        docker tag openshift/jenkins-slave-base-centos7:latest fabric8/jenkins-slave-base-centos7:${newVersion}
        docker push fabric8/jenkins-slave-base-centos7:${newVersion}

        updateDownstreamRepos ${newVersion}
    fi
}

function updateDownstreamRepos() {
    local newVersion=${1}

    # Random string
    uid=$(python -c 'import uuid;print uuid.uuid4()')
    branch="versionUpdate${uid}"
    message="Update jenkins base image to ${newVersion}"

    git config --global user.name "FABRIC8 CD autobot"
    git config --global user.email fabric8cd@gmail.com

    set +x
    echo git clone https://XXXX@github.com/fabric8io/openshift-jenkins-s2i-config.git --depth=1 /tmp/openshift-jenkins-s2i
    git clone https://$(echo ${FABRIC8_HUB_TOKEN}|base64 --decode)@github.com/fabric8io/openshift-jenkins-s2i-config.git --depth=1 /tmp/openshift-jenkins-s2i
    set -x
    cd /tmp/openshift-jenkins-s2i
    git checkout -b ${branch}
    sed -i "s/baseImageVerion = .*/baseImageVerion = \"${newVersion}\"/g" Jenkinsfile
    git commit Jenkinsfile -m "${message}"

    git push -u origin ${branch}
    set +x
    echo "hub pull-request -m ${message}"
    GITHUB_TOKEN=$(echo ${FABRIC8_HUB_TOKEN}|base64 --decode) /usr/local/bin/hub pull-request -m "${message}"
    set -x
}

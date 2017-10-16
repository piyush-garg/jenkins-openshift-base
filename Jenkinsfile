#!/usr/bin/groovy
@Library('github.com/fabric8io/fabric8-pipeline-library@master')
def name = 'jenkins-openshift-base'
def org = 'fabric8io'
dockerTemplate{
    s2iNode(s2iImage: 'fabric8/s2i-builder:0.0.3'){
        git "https://github.com/${org}/${name}.git"
        if (env.BRANCH_NAME.startsWith('PR-')) {
            echo 'Running CI pipeline'
            container('s2i') {
                sh 'make build VERSION=2'
            }

            def newVersion = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
            stage ('push to dockerhub'){
                container('docker') {
                    sh "docker tag openshift/jenkins-2-centos7:latest fabric8/jenkins-openshift-base:${newVersion}"
                    sh "docker push fabric8/jenkins-openshift-base:${newVersion}"
                }
            }

        } else if (env.BRANCH_NAME.equals('master')) {
            echo 'Running CD pipeline'
            def newVersion = getNewVersion {}

            stage ('build'){
                container('s2i') {
                    sh 'make build VERSION=2'
                }
            }

            stage ('push to dockerhub'){
                container('docker') {
                    sh "docker tag openshift/jenkins-2-centos7:latest fabric8/jenkins-openshift-base:${newVersion}"
                    sh "docker push fabric8/jenkins-openshift-base:${newVersion}"
                }
            }
            updateDownstreamRepos(newVersion)
        }
    }
}

def updateDownstreamRepos(newVersion){
    container('s2i') {
        sh 'chmod 600 /root/.ssh-git/ssh-key'
        sh 'chmod 600 /root/.ssh-git/ssh-key.pub'
        sh 'chmod 700 /root/.ssh-git'

        git "git@github.com:fabric8io/openshift-jenkins-s2i-config.git"
        def flow = new io.fabric8.Fabric8Commands()

        sh "git config user.email fabric8cd@gmail.com"
        sh "git config user.name fabric8-cd"

        def uid = UUID.randomUUID().toString()
        def branch = "versionUpdate${uid}"
        sh "git checkout -b ${branch}"

        sh "sed -i 's/baseImageVerion = .*/baseImageVerion = \"${newVersion}\"/g' Jenkinsfile"
        def message = "Update jenkins base image to ${newVersion}"
        sh "git add Jenkinsfile"
        sh "git commit -m \"${message}\""
        sh "git push origin ${branch}"
        def prId = flow.createPullRequest(message, 'fabric8io/openshift-jenkins-s2i-config', branch)
        //flow.mergePR(gitRepo, prId)
    }
}
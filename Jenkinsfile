pipeline {
  agent {
    label 'X86-64-MULTI'
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '60'))
    parallelsAlwaysFailFast()
  }
  // Input to determine if this is a package check
  parameters {
    string(defaultValue: 'false', description: 'package check run', name: 'PACKAGE_CHECK')
  }
  // Configuration for the variables used for this specific repo
  environment {
    GITHUB_TOKEN = credentials('62cf71a9-6168-48cb-89cf-af0f04c752f2')
    GIT_SIGNING_KEY = credentials('7fd3fbe4-e8ca-4d0f-8aa2-8c55ef937b73') 
    BUILD_VERSION_ARG = 'OS'
    LS_USER = 'annie444'
    LS_REPO = 'docker-orcaslicer'
    EXT_USER = 'SoftFever'
    EXT_REPO = 'OrcaSlicer'
    CONTAINER_NAME = 'orcaslicer'
    IMAGE = 'annie444/orcaslicer'
    DEV_IMAGE = 'annie444/dev-orcaslicer'
    PR_IMAGE = 'annie444/pr-orcaslicer'
    DIST_IMAGE = 'ubuntu'
    MULTIARCH='false'
    TITLE='OrcaSlicer'
    CI='false'
    CI_WEB='false'
    CI_PORT='80'
    CI_SSL='true'
    CI_DELAY='30'
    CI_DOCKERENV=''
    CI_AUTH=''
    CI_WEBPATH=''
    S3_ENDPOINT = 's3.jpeg.gay'
    S3_BUCKET = 'ci-tests.jpeg.gay'
    S3_REGION = 'us-west-2'
  }
  stages {
    stage("Set git config"){
      steps{
        sh '''#!/bin/bash
          ssh-keygen -y -f ${GIT_SIGNING_KEY} > ${GIT_SIGNING_KEY}.pub
          echo "Using $(ssh-keygen -lf ${GIT_SIGNING_KEY}) to sign commits"
          git config --global gpg.format ssh
          git config --global user.signingkey ${GIT_SIGNING_KEY}
          git config --global commit.gpgsign true
        '''
      }
    }
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        echo "Running on node: ${NODE_NAME}"
        sh '''#! /bin/bash
              containers=$(docker ps -aq)
              if [[ -n "${containers}" ]]; then
                docker stop ${containers}
              fi
              docker system prune -af --volumes || : '''
        script{
          env.EXIT_STATUS = ''
          env.LS_RELEASE = sh(
            script: '''docker run --rm quay.io/skopeo/stable:v1 inspect docker://ghcr.io/${LS_USER}/${CONTAINER_NAME}:latest 2>/dev/null | jq -r '.Labels.build_version' | awk '{print $3}' | grep '\\-ls' || : ''',
            returnStdout: true).trim()
          env.LS_RELEASE_NOTES = sh(
            script: '''cat readme-vars.yml | awk -F \\" '/date: "[0-9][0-9].[0-9][0-9].[0-9][0-9]:/ {print $4;exit;}' | sed -E ':a;N;$!ba;s/\\r{0,1}\\n/\\\\n/g' ''',
            returnStdout: true).trim()
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.GH_DEFAULT_BRANCH = sh(
            script: '''git remote show origin | grep "HEAD branch:" | sed 's|.*HEAD branch: ||' ''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.LS_USER + '/' + env.LS_REPO + '/commit/' + env.GIT_COMMIT
          env.LINK = 'https://github.com/users/' + env.LS_USER + '/packages/container/' + env.IMAGE
          env.EXT_RELEASE = sh(
            script: '''curl -H "Authorization: token ${GITHUB_TOKEN}" -s https://api.github.com/repos/${EXT_USER}/${EXT_REPO}/releases/latest | jq -r '. | .tag_name' ''',
            returnStdout: true
          ).trim()
          env.PULL_REQUEST = env.CHANGE_ID
          env.TEMPLATED_FILES = 'Jenkinsfile README.md LICENSE .editorconfig ./.github/CONTRIBUTING.md ./.github/FUNDING.yml ./.github/ISSUE_TEMPLATE/config.yml ./.github/ISSUE_TEMPLATE/issue.bug.yml ./.github/ISSUE_TEMPLATE/issue.feature.yml ./.github/PULL_REQUEST_TEMPLATE.md ./.github/workflows/external_trigger_scheduler.yml ./.github/workflows/greetings.yml ./.github/workflows/package_trigger_scheduler.yml ./.github/workflows/call_issue_pr_tracker.yml ./.github/workflows/call_issues_cron.yml ./.github/workflows/permissions.yml ./.github/workflows/external_trigger.yml'
          env.RELEASE_LINK = 'https://github.com/' + env.EXT_USER + '/' + env.EXT_REPO + '/releases/tag/' + env.EXT_RELEASE
        }
        sh '''#! /bin/bash
              echo "The default github branch detected as ${GH_DEFAULT_BRANCH}" '''
        echo "The current ${EXT_REPO} version is ${EXT_RELEASE}"
        script{
          env.LS_RELEASE_NUMBER = sh(
            script: '''echo ${LS_RELEASE} |sed 's/^.*-ls//g' ''',
            returnStdout: true).trim()
        }
        script{
          env.LS_TAG_NUMBER = sh(
            script: '''#! /bin/bash
                       tagsha=$(git rev-list -n 1 ${LS_RELEASE} 2>/dev/null)
                       if [ "${tagsha}" == "${COMMIT_SHA}" ]; then
                         echo ${LS_RELEASE_NUMBER}
                       elif [ -z "${GIT_COMMIT}" ]; then
                         echo ${LS_RELEASE_NUMBER}
                       else
                         echo $((${LS_RELEASE_NUMBER} + 1))
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* #######################
       Package Version Tagging
       ####################### */
    // Grab the current package versions in Git to determine package tag
    stage("Set Package tag"){
      steps{
        script{
          env.PACKAGE_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e package_versions.txt ] ; then
                         cat package_versions.txt | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    // Sanitize the release tag and strip illegal docker or github characters
    stage("Sanitize tag"){
      steps{
        script{
          env.EXT_RELEASE_CLEAN = sh(
            script: '''echo ${EXT_RELEASE} | sed 's/[~,%@+;:/ ]//g' ''',
            returnStdout: true).trim()

          def semver = env.EXT_RELEASE_CLEAN =~ /(\d+)\.(\d+)\.(\d+)/
          if (semver.find()) {
            env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${semver[0][3]}"
          } else {
            semver = env.EXT_RELEASE_CLEAN =~ /(\d+)\.(\d+)(?:\.(\d+))?(.*)/
            if (semver.find()) {
              if (semver[0][3]) {
                env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${semver[0][3]}"
              } else if (!semver[0][3] && !semver[0][4]) {
                env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${(new Date()).format('YYYYMMdd')}"
              }
            }
          }

          if (env.SEMVER != null) {
            if (BRANCH_NAME != "${env.GH_DEFAULT_BRANCH}") {
              env.SEMVER = "${env.SEMVER}-${BRANCH_NAME}"
            }
            println("SEMVER: ${env.SEMVER}")
          } else {
            println("No SEMVER detected")
          }

        }
      }
    }
    // If this is a master build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.IMAGE
          env.GITHUBIMAGE = 'ghcr.io/' + env.LS_USER + '/' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          env.EXT_RELEASE_TAG = 'version-' + env.EXT_RELEASE_CLEAN
          env.VERSIONS_LINK = 'https://github.com/users/' + env.LS_USER + '/packages/container/' + env.IMAGE + '/versions'
          env.BUILDCACHE = 'ghcr.io/' + env.LS_USER + '/dev-buildcache'
        }
      }
    }
    // If this is a dev build use dev docker endpoints
    stage("Set ENV dev build"){
      when {
        not {branch "master"}
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DEV_IMAGE
          env.GITHUBIMAGE = 'ghcr.io/' + env.LS_USER + '/dev-' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.EXT_RELEASE_TAG = 'version-' + env.EXT_RELEASE_CLEAN
          env.VERSIONS_LINK = 'https://github.com/users/' + env.LS_USER + '/packages/container/' + env.DEV_IMAGE + '/versions'
          env.BUILDCACHE = 'ghcr.io/' + env.LS_USER + '/dev-buildcache'
        }
      }
    }
    // If this is a pull request build use dev docker endpoints
    stage("Set ENV PR build"){
      when {
        not {environment name: 'CHANGE_ID', value: ''}
      }
      steps {
        script{
          env.IMAGE = env.PR_IMAGE
          env.GITHUBIMAGE = 'ghcr.io/' + env.LS_USER + '/pr-' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '-pr-' + env.PULL_REQUEST + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '-pr-' + env.PULL_REQUEST
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '-pr-' + env.PULL_REQUEST
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '-pr-' + env.PULL_REQUEST
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '-pr-' + env.PULL_REQUEST
          env.EXT_RELEASE_TAG = 'version-' + env.EXT_RELEASE_CLEAN
          env.CODE_URL = 'https://github.com/' + env.LS_USER + '/' + env.LS_REPO + '/pull/' + env.PULL_REQUEST
          env.VERSIONS_LINK = 'https://github.com/users/' + env.LS_USER + '/packages/container/' + env.PR_IMAGE + '/versions'
          env.BUILDCACHE = 'ghcr.io/' + env.LS_USER + '/dev-buildcache'
        }
      }
    }
    // Run ShellCheck
    stage('ShellCheck') {
      when {
        environment name: 'CI', value: 'true'
      }
      steps {
        withCredentials([
          string(credentialsId: 'ci-tests-s3-key-id', variable: 'S3_KEY'),
          string(credentialsId: 'ci-tests-s3-secret-access-key', variable: 'S3_SECRET')
        ]) {
          script{
            env.SHELLCHECK_URL = 'https://ci-tests.jpeg.gay/' + env.IMAGE + '/' + env.META_TAG + '/shellcheck-result.xml'
          }
          sh '''curl -sL https://raw.githubusercontent.com/linuxserver/docker-jenkins-builder/master/checkrun.sh | /bin/bash'''
          sh '''#! /bin/bash
                docker run --rm \
                  -v ${WORKSPACE}:/mnt \
                  -e AWS_ACCESS_KEY_ID=\"${S3_KEY}\" \
                  -e AWS_SECRET_ACCESS_KEY=\"${S3_SECRET}\" \
                  ghcr.io/linuxserver/baseimage-alpine:3.20 s6-envdir -fn -- /var/run/s6/container_environment /bin/bash -c "\
                    apk add --no-cache python3 && \
                    python3 -m venv /lsiopy && \
                    pip install --no-cache-dir -U pip && \
                    pip install --no-cache-dir s3cmd && \
                    s3cmd put --no-preserve --acl-public -m text/xml --region ${S3_REGION} --host ${S3_ENDPOINT} /mnt/shellcheck-result.xml s3://${S3_BUCKET}/${IMAGE}/${META_TAG}/shellcheck-result.xml" || :'''
        }
      }
    }
    // If this is a master build check the S6 service file perms
    stage("Check S6 Service file Permissions"){
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        script{
          sh '''#! /bin/bash
            WRONG_PERM=$(find ./  -path "./.git" -prune -o \\( -name "run" -o -name "finish" -o -name "check" \\) -not -perm -u=x,g=x,o=x -print)
            if [[ -n "${WRONG_PERM}" ]]; then
              echo "The following S6 service files are missing the executable bit; canceling the faulty build: ${WRONG_PERM}"
              exit 1
            else
              echo "S6 service file perms look good."
            fi '''
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to LS Repo
    stage('Build-Single') {
      when {
        expression {
          env.MULTIARCH == 'false' || params.PACKAGE_CHECK == 'true'
        }
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Running on node: ${NODE_NAME}"
        sh "sed -r -i 's|(^FROM .*)|\\1\\n\\nENV LSIO_FIRST_PARTY=true|g' Dockerfile"
        sh "docker buildx build \
          --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
          --label \"org.opencontainers.image.authors=linuxserver.io\" \
          --label \"org.opencontainers.image.url=https://github.com/${LS_USER}/${LS_REPO}/packages\" \
          --label \"org.opencontainers.image.documentation=https://docs.linuxserver.io/images/${LS_REPO}\" \
          --label \"org.opencontainers.image.source=https://github.com/${LS_USER}/${LS_REPO}\" \
          --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-ls${LS_TAG_NUMBER}\" \
          --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
          --label \"org.opencontainers.image.vendor=jpeg.gay\" \
          --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
          --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
          --label \"org.opencontainers.image.title=${TITLE}\" \
          --label \"org.opencontainers.image.description=${TITLE} image by linuxserver.io\" \
          --no-cache --pull -t ${IMAGE}:${META_TAG} --platform=linux/amd64 \
          --provenance=false --sbom=false --builder=container --load \
          --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
        sh '''#! /bin/bash
              set -e
              IFS=',' read -ra CACHE <<< "$BUILDCACHE"
              for i in "${CACHE[@]}"; do
                docker tag ${IMAGE}:${META_TAG} ${i}:amd64-${COMMIT_SHA}-${BUILD_NUMBER}
              done
           '''
        retry_backoff(5,5) {
            sh '''#! /bin/bash
                  set -e
                  echo $GITHUB_TOKEN | docker login ghcr.io -u ${LS_USER} --password-stdin
                  if [[ "${PACKAGE_CHECK}" != "true" ]]; then
                    IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                    for i in "${CACHE[@]}"; do
                      docker push ${i}:amd64-${COMMIT_SHA}-${BUILD_NUMBER} &
                    done
                    wait
                  fi
              '''
        }
      }
    }
    // Build MultiArch Docker containers for push to LS Repo
    stage('Build-Multi') {
      when {
        allOf {
          environment name: 'MULTIARCH', value: 'true'
          expression { params.PACKAGE_CHECK == 'false' }
        }
        environment name: 'EXIT_STATUS', value: ''
      }
      parallel {
        stage('Build X86') {
          steps {
            echo "Running on node: ${NODE_NAME}"
            sh "sed -r -i 's|(^FROM .*)|\\1\\n\\nENV LSIO_FIRST_PARTY=true|g' Dockerfile"
            sh "docker buildx build \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=linuxserver.io\" \
              --label \"org.opencontainers.image.url=https://github.com/${LS_USER}/${LS_REPO}/packages\" \
              --label \"org.opencontainers.image.documentation=https://docs.linuxserver.io/images/${LS_REPO}\" \
              --label \"org.opencontainers.image.source=https://github.com/${LS_USER}/${LS_REPO}\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-ls${LS_TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=jpeg.gay\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=${TITLE}\" \
              --label \"org.opencontainers.image.description=${TITLE} image by linuxserver.io\" \
              --no-cache --pull -t ${IMAGE}:amd64-${META_TAG} --platform=linux/amd64 \
              --provenance=false --sbom=false --builder=container --load \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
            sh '''#! /bin/bash
                  set -e
                  IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                  for i in "${CACHE[@]}"; do
                    docker tag ${IMAGE}:amd64-${META_TAG} ${i}:amd64-${COMMIT_SHA}-${BUILD_NUMBER}
                  done
               '''
            retry_backoff(5,5) {
                sh '''#! /bin/bash
                      set -e
                      echo $GITHUB_TOKEN | docker login ghcr.io -u ${LS_USER} --password-stdin
                      if [[ "${PACKAGE_CHECK}" != "true" ]]; then
                        IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                        for i in "${CACHE[@]}"; do
                          docker push ${i}:amd64-${COMMIT_SHA}-${BUILD_NUMBER} &
                        done
                        wait
                      fi
                  '''
            }
          }
        }
        stage('Build ARM64') {
          agent {
            label 'ARM64'
          }
          steps {
            echo "Running on node: ${NODE_NAME}"
            sh "sed -r -i 's|(^FROM .*)|\\1\\n\\nENV LSIO_FIRST_PARTY=true|g' Dockerfile.aarch64"
            sh "docker buildx build \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=linuxserver.io\" \
              --label \"org.opencontainers.image.url=https://github.com/${LS_USER}/${LS_REPO}/packages\" \
              --label \"org.opencontainers.image.documentation=https://docs.linuxserver.io/images/${LS_REPO}\" \
              --label \"org.opencontainers.image.source=https://github.com/${LS_USER}/${LS_REPO}\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-ls${LS_TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=jpeg.gay\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=${TITLE}\" \
              --label \"org.opencontainers.image.description=${TITLE} image by linuxserver.io\" \
              --no-cache --pull -f Dockerfile.aarch64 -t ${IMAGE}:arm64v8-${META_TAG} --platform=linux/arm64 \
              --provenance=false --sbom=false --builder=container --load \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
            sh '''#! /bin/bash
                  set -e
                  IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                  for i in "${CACHE[@]}"; do
                    docker tag ${IMAGE}:arm64v8-${META_TAG} ${i}:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  done
               '''
            retry_backoff(5,5) {
                sh '''#! /bin/bash
                      set -e
                      echo $GITHUB_TOKEN | docker login ghcr.io -u ${LS_USER} --password-stdin
                      if [[ "${PACKAGE_CHECK}" != "true" ]]; then
                        IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                        for i in "${CACHE[@]}"; do
                          docker push ${i}:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} &
                        done
                        wait
                      fi
                  '''
            }
            sh '''#! /bin/bash
                  containers=$(docker ps -aq)
                  if [[ -n "${containers}" ]]; then
                    docker stop ${containers}
                  fi
                  docker system prune -af --volumes || :
               '''
          }
        }
      }
    }
    // Take the image we just built and dump package versions for comparison
    stage('Update-packages') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#! /bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              if [ "${MULTIARCH}" == "true" ] && [ "${PACKAGE_CHECK}" != "true" ]; then
                LOCAL_CONTAINER=${IMAGE}:amd64-${META_TAG}
              else
                LOCAL_CONTAINER=${IMAGE}:${META_TAG}
              fi
              touch ${TEMPDIR}/package_versions.txt
              docker run --rm \
                -v /var/run/docker.sock:/var/run/docker.sock:ro \
                -v ${TEMPDIR}:/tmp \
                ghcr.io/anchore/syft:latest \
                ${LOCAL_CONTAINER} -o table=/tmp/package_versions.txt
              NEW_PACKAGE_TAG=$(md5sum ${TEMPDIR}/package_versions.txt | cut -c1-8 )
              echo "Package tag sha from current packages in buit container is ${NEW_PACKAGE_TAG} comparing to old ${PACKAGE_TAG} from github"
              if [ "${NEW_PACKAGE_TAG}" != "${PACKAGE_TAG}" ]; then
                git clone https://github.com/${LS_USER}/${LS_REPO}.git ${TEMPDIR}/${LS_REPO}
                git --git-dir ${TEMPDIR}/${LS_REPO}/.git checkout -f master
                cp ${TEMPDIR}/package_versions.txt ${TEMPDIR}/${LS_REPO}/
                cd ${TEMPDIR}/${LS_REPO}/
                wait
                git add package_versions.txt
                git commit -m 'Bot Updating Package Versions'
                git pull https://${LS_USER}:${GITHUB_TOKEN}@github.com/${LS_USER}/${LS_REPO}.git master
                git push https://${LS_USER}:${GITHUB_TOKEN}@github.com/${LS_USER}/${LS_REPO}.git master
                echo "true" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag updated, stopping build process"
              else
                echo "false" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag is same as previous continue with build process"
              fi
              rm -Rf ${TEMPDIR}'''
        script{
          env.PACKAGE_UPDATED = sh(
            script: '''cat /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the package file was just updated
    stage('PACKAGE-exit') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    // Exit the build if this is just a package check and there are no changes to push
    stage('PACKAGECHECK-exit') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
        expression {
          params.PACKAGE_CHECK == 'true'
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* #######
       Testing
       ####### */
    // Run Container tests
    stage('Test') {
      when {
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          string(credentialsId: 'ci-tests-s3-key-id', variable: 'S3_KEY'),
          string(credentialsId: 'ci-tests-s3-secret-access-key	', variable: 'S3_SECRET')
        ]) {
          script{
            env.CI_URL = 'https://ci-tests.jpeg.gay/' + env.IMAGE + '/' + env.META_TAG + '/index.html'
            env.CI_JSON_URL = 'https://ci-tests.jpeg.gay/' + env.IMAGE + '/' + env.META_TAG + '/report.json'
          }
          sh '''#! /bin/bash
                set -e
                if grep -q 'docker-baseimage' <<< "${LS_REPO}"; then
                  echo "Detected baseimage, setting LSIO_FIRST_PARTY=true"
                  if [ -n "${CI_DOCKERENV}" ]; then
                    CI_DOCKERENV="LSIO_FIRST_PARTY=true|${CI_DOCKERENV}"
                  else
                    CI_DOCKERENV="LSIO_FIRST_PARTY=true"
                  fi
                fi
                docker pull ghcr.io/${LS_USER}/ci:latest
                if [ "${MULTIARCH}" == "true" ]; then
                  docker pull ghcr.io/${LS_USER}/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} --platform=arm64
                  docker tag ghcr.io/${LS_USER}/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm64v8-${META_TAG}
                fi
                docker run --rm \
                --shm-size=1gb \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -e IMAGE=\"${IMAGE}\" \
                -e DOCKER_LOGS_TIMEOUT=\"${CI_DELAY}\" \
                -e TAGS=\"${CI_TAGS}\" \
                -e META_TAG=\"${META_TAG}\" \
                -e RELEASE_TAG=\"latest\" \
                -e PORT=\"${CI_PORT}\" \
                -e S3_ENDPOINT=\"${S3_ENDPOINT}\" \
                -e S3_BUCKET=\"${S3_BUCKET}\" \
                -e S3_REGION=\"${S3_REGION}\" \
                -e SSL=\"${CI_SSL}\" \
                -e BASE=\"${DIST_IMAGE}\" \
                -e SECRET_KEY=\"${S3_SECRET}\" \
                -e ACCESS_KEY=\"${S3_KEY}\" \
                -e DOCKER_ENV=\"${CI_DOCKERENV}\" \
                -e WEB_SCREENSHOT=\"${CI_WEB}\" \
                -e WEB_AUTH=\"${CI_AUTH}\" \
                -e WEB_PATH=\"${CI_WEBPATH}\" \
                -e NODE_NAME=\"${NODE_NAME}\" \
                -t ghcr.io/${LS_USER}/ci:latest \
                python3 test_build.py'''
        }
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        retry_backoff(5,5) {
          sh '''#! /bin/bash
                set -e
                for PUSHIMAGE in "${GITHUBIMAGE}"; do
                  PUSHIMAGEPLUS="${PUSHIMAGE}"
                  IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                  for i in "${CACHE[@]}"; do
                      if [[ "${PUSHIMAGEPLUS}" == "$(cut -d "/" -f1 <<< ${i})"* ]]; then
                          CACHEIMAGE=${i}
                      fi
                  done
                  docker buildx imagetools create --prefer-index=false -t ${PUSHIMAGE}:${META_TAG} -t ${PUSHIMAGE}:latest -t ${PUSHIMAGE}:${EXT_RELEASE_TAG} ${CACHEIMAGE}:amd64-${COMMIT_SHA}-${BUILD_NUMBER}
                  if [ -n "${SEMVER}" ]; then
                    docker buildx imagetools create --prefer-index=false -t ${PUSHIMAGE}:${SEMVER} ${CACHEIMAGE}:amd64-${COMMIT_SHA}-${BUILD_NUMBER}
                  fi
                done
              '''
        }
      }
    }
    // If this is a multi arch release push all images and define the manifest
    stage('Docker-Push-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        retry_backoff(5,5) {
          sh '''#! /bin/bash
                set -e
                for MANIFESTIMAGE in "${GITHUBIMAGE}"; do
                  MANIFESTIMAGEPLUS="${MANIFESTIMAGE}"
                  IFS=',' read -ra CACHE <<< "$BUILDCACHE"
                  for i in "${CACHE[@]}"; do
                      if [[ "${MANIFESTIMAGEPLUS}" == "$(cut -d "/" -f1 <<< ${i})"* ]]; then
                          CACHEIMAGE=${i}
                      fi
                  done
                  docker buildx imagetools create --prefer-index=false -t ${MANIFESTIMAGE}:amd64-${META_TAG} -t ${MANIFESTIMAGE}:amd64-latest -t ${MANIFESTIMAGE}:amd64-${EXT_RELEASE_TAG} ${CACHEIMAGE}:amd64-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker buildx imagetools create --prefer-index=false -t ${MANIFESTIMAGE}:arm64v8-${META_TAG} -t ${MANIFESTIMAGE}:arm64v8-latest -t ${MANIFESTIMAGE}:arm64v8-${EXT_RELEASE_TAG} ${CACHEIMAGE}:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  if [ -n "${SEMVER}" ]; then
                    docker buildx imagetools create --prefer-index=false -t ${MANIFESTIMAGE}:amd64-${SEMVER} ${CACHEIMAGE}:amd64-${COMMIT_SHA}-${BUILD_NUMBER}
                    docker buildx imagetools create --prefer-index=false -t ${MANIFESTIMAGE}:arm64v8-${SEMVER} ${CACHEIMAGE}:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  fi
                done
                for MANIFESTIMAGE in "${IMAGE}" "${GITLABIMAGE}" "${GITHUBIMAGE}" "${QUAYIMAGE}"; do
                  docker buildx imagetools create -t ${MANIFESTIMAGE}:latest ${MANIFESTIMAGE}:amd64-latest ${MANIFESTIMAGE}:arm64v8-latest
                  docker buildx imagetools create -t ${MANIFESTIMAGE}:${META_TAG} ${MANIFESTIMAGE}:amd64-${META_TAG} ${MANIFESTIMAGE}:arm64v8-${META_TAG}

                  docker buildx imagetools create -t ${MANIFESTIMAGE}:${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:amd64-${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:arm64v8-${EXT_RELEASE_TAG}
                  if [ -n "${SEMVER}" ]; then
                    docker buildx imagetools create -t ${MANIFESTIMAGE}:${SEMVER} ${MANIFESTIMAGE}:amd64-${SEMVER} ${MANIFESTIMAGE}:arm64v8-${SEMVER}
                  fi
                done
              '''
        }
      }
    }
    // If this is a public release tag it in the LS Github
    stage('Github-Tag-Push-Release') {
      when {
        branch "master"
        expression {
          env.LS_RELEASE != env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
        }
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Pushing New tag for current commit ${META_TAG}"
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/git/tags \
        -d '{"tag":"'${META_TAG}'",\
             "object": "'${COMMIT_SHA}'",\
             "message": "Tagging Release '${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}' to master",\
             "type": "commit",\
             "tagger": {"name": "${LS_USER}","email": "ci@jpeg.gay","date": "'${GITHUB_DATE}'"}}' '''
        echo "Pushing New release for Tag"
        sh '''#! /bin/bash
              echo "Updating base packages to ${PACKAGE_TAG}" > releasebody.json
              echo '{"tag_name":"'${META_TAG}'",\
                     "target_commitish": "master",\
                     "name": "'${META_TAG}'",\
                     "body": "**CI Report:**\\n\\n'${CI_URL:-N/A}'\\n\\n**LinuxServer Changes:**\\n\\n'${LS_RELEASE_NOTES}'\\n\\n**OS Changes:**\\n\\n' > start
              printf '","draft": false,"prerelease": false}' >> releasebody.json
              paste -d'\\0' start releasebody.json > releasebody.json.done
              curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/releases -d @releasebody.json.done'''
      }
    }
    // Add protection to the release branch
    stage('Github-Release-Branch-Protection') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Setting up protection for release branch master"
        sh '''#! /bin/bash
          curl -H "Authorization: token ${GITHUB_TOKEN}" -X PUT https://api.github.com/repos/${LS_USER}/${LS_REPO}/branches/master/protection \
          -d $(jq -c .  << EOF
            {
              "required_status_checks": null,
              "enforce_admins": false,
              "required_pull_request_reviews": {
                "dismiss_stale_reviews": false,
                "require_code_owner_reviews": false,
                "require_last_push_approval": false,
                "required_approving_review_count": 1
              },
              "restrictions": null,
              "required_linear_history": false,
              "allow_force_pushes": false,
              "allow_deletions": false,
              "block_creations": false,
              "required_conversation_resolution": true,
              "lock_branch": false,
              "allow_fork_syncing": false,
              "required_signatures": false
            }
EOF
          ) '''
      }
    }
    // If this is a Pull request send the CI link as a comment on it
    stage('Pull Request Comment') {
      when {
        not {environment name: 'CHANGE_ID', value: ''}
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#! /bin/bash
            # Function to retrieve JSON data from URL
            get_json() {
              local url="$1"
              local response=$(curl -s "$url")
              if [ $? -ne 0 ]; then
                echo "Failed to retrieve JSON data from $url"
                return 1
              fi
              local json=$(echo "$response" | jq .)
              if [ $? -ne 0 ]; then
                echo "Failed to parse JSON data from $url"
                return 1
              fi
              echo "$json"
            }

            build_table() {
              local data="$1"

              # Get the keys in the JSON data
              local keys=$(echo "$data" | jq -r 'to_entries | map(.key) | .[]')

              # Check if keys are empty
              if [ -z "$keys" ]; then
                echo "JSON report data does not contain any keys or the report does not exist."
                return 1
              fi

              # Build table header
              local header="| Tag | Passed |\\n| --- | --- |\\n"

              # Loop through the JSON data to build the table rows
              local rows=""
              for build in $keys; do
                local status=$(echo "$data" | jq -r ".[\\"$build\\"].test_success")
                if [ "$status" = "true" ]; then
                  status="✅"
                else
                  status="❌"
                fi
                local row="| "$build" | "$status" |\\n"
                rows="${rows}${row}"
              done

              local table="${header}${rows}"
              local escaped_table=$(echo "$table" | sed 's/\"/\\\\"/g')
              echo "$escaped_table"
            }

            if [[ "${CI}" = "true" ]]; then
              # Retrieve JSON data from URL
              data=$(get_json "$CI_JSON_URL")
              # Create table from JSON data
              table=$(build_table "$data")
              echo -e "$table"

              curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$LS_USER/$LS_REPO/issues/$PULL_REQUEST/comments" \
                -d "{\\"body\\": \\"I am a bot, here are the test results for this PR: \\n${CI_URL}\\n${SHELLCHECK_URL}\\n${table}\\"}"
            else
              curl -X POST -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/$LS_USER/$LS_REPO/issues/$PULL_REQUEST/comments" \
                -d "{\\"body\\": \\"I am a bot, here is the pushed image/manifest for this PR: \\n\\n\\`${GITHUBIMAGE}:${META_TAG}\\`\\"}"
            fi
            '''

      }
    }
  }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      sh '''#!/bin/bash
            rm -rf /config/.ssh/id_sign
            rm -rf /config/.ssh/id_sign.pub
            git config --global --unset gpg.format
            git config --global --unset user.signingkey
            git config --global --unset commit.gpgsign
        '''
    }
    cleanup {
      sh '''#! /bin/bash
            echo "Performing docker system prune!!"
            containers=$(docker ps -aq)
            if [[ -n "${containers}" ]]; then
              docker stop ${containers}
            fi
            docker system prune -af --volumes || :
         '''
      cleanWs()
    }
  }
}

def retry_backoff(int max_attempts, int power_base, Closure c) {
  int n = 0
  while (n < max_attempts) {
    try {
      c()
      return
    } catch (err) {
      if ((n + 1) >= max_attempts) {
        throw err
      }
      sleep(power_base ** n)
      n++
    }
  }
  return
}

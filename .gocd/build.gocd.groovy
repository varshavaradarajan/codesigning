/*
 * Copyright 2019 ThoughtWorks, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

def fetchArtifactTask = {String osType ->
  return new FetchArtifactTask(false, {
                    pipeline = 'installers'
                    stage = 'dist'
                    job = 'dist'
                    source = "dist/${osType}"
                    destination = "codesigning/src"
  })
}

def cleanTasks = {
  return [
          new ExecTask({
            commandLine = ['git', 'clean', '-dffx']
            workingDir = 'codesigning'
          })
        ]

}
def createRakeTask = {String osType ->
  return new ExecTask({
                    commandLine = ["rake", "--trace", "${osType}:sign"]
                    workingDir = 'codesigning'
  })
}

def publishArtifactTask = { String osType ->
  return new BuildArtifact('build', {

                    source = "codesigning/out/${osType}"
                    destination = "dist"
  })
}

GoCD.script {
  environments {
    environment('internal') {
      pipelines = ['code-sign', 'promote-stable-release']
    }
  }

  pipelines {
    pipeline('code-sign') { thisPipeline ->
      group = 'go-cd'
      environmentVariables = [
        'STABLE_DOWNLOAD_BUCKET': 'ketanpkr-test-stable',
        'EXPERIMENTAL_DOWNLOAD_BUCKET':'ketanpkr-test-experimental/experimental',
        'UPDATE_CHECK_BUCKET':'ketanpkr-test-update-check'
      ]

      materials() {
        git('codesigning') {
          url = 'https://github.com/ketan/codesigning'
          destination = "codesigning"
        }
        svn('signing-keys') {
          url = "https://github.com/gocd-private/signing-keys/trunk"
          username = "gocd-ci-user"
          encryptedPassword = "AES:taOvOCaXsoVwzIi+xIGLdA==:GSfhZ6KKt6MXKp/wdYYoyBQKKzbTiyDa+35kDgkEIOF75s9lzerGInbqbUM7nUKc"
          destination = "signing-keys"
        }
        dependency('installers') {
          pipeline = 'installers'
          stage = 'dist'
        }
      }

      stages {
        stage('sign') {
          cleanWorkingDir = true
          secureEnvironmentVariables = [
            GOCD_GPG_PASSPHRASE: 'AES:7lAutKoRKMuSnh3Sbg9DeQ==:8fhND9w/8AWw6dJhmWpTcCdKSsEcOzriQNiKFZD6XtN+sJvZ65NH/QFXRNiy192+SSTKsbhOrFmw+kAKt5+MH1Erd6H54zJjpSgvJUmsJaQ=',
            AWS_ACCESS_KEY_ID: 'AES:LrDnmFW7ccFMuNzSQOUVUA==:S7wAb+ax9rKPi11h8x++3+ZjxHAX0SAGySxHUudsyh4=',
            AWS_SECRET_ACCESS_KEY: 'AES:YTpL7c+j85Su27egw84Cxg==:rVtWJySwMDMkdOGW4Md7LKkyxJc8X1kJBwXE3ebQfhJdTo7mCAn8jelLSyUAcEFI'
          ]

          jobs {
            job('rpm') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                addAll(cleanTasks())
                add(fetchArtifactTask('rpm'))
                add(fetchArtifactTask('meta'))
                bash {
                  commandString = 'rake --trace rpm:sign rpm:upload[${EXPERIMENTAL_DOWNLOAD_BUCKET}] yum:createrepo[${EXPERIMENTAL_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
            job('deb') {
              elasticProfileId = 'ubuntu-16.04'
              tasks {
                addAll(cleanTasks())
                add(fetchArtifactTask('deb'))
                add(fetchArtifactTask('meta'))
                bash {
                  commandString = 'rake --trace deb:sign[${EXPERIMENTAL_DOWNLOAD_BUCKET}] deb:upload[${EXPERIMENTAL_DOWNLOAD_BUCKET}] apt:createrepo[${EXPERIMENTAL_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
            job('zip') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                add(fetchArtifactTask('zip'))
                add(fetchArtifactTask('meta'))
                bash {
                  commandString = 'rake --trace zip:sign zip:upload[${EXPERIMENTAL_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
            job('win') {
              elasticProfileId = 'window-dev-build'
              tasks {
                addAll(cleanTasks())
                add(fetchArtifactTask('win'))
                add(fetchArtifactTask('meta'))
                exec {
                  commandLine = ['rake' ,'--trace','win:sign', 'win:upload[%EXPERIMENTAL_DOWNLOAD_BUCKET%]']
                  workingDir = 'codesigning'
                }
              }
            }
            job('osx') {
              resources = ['mac', 'signer']
              tasks {
                addAll(cleanTasks())
                add(fetchArtifactTask('osx'))
                add(fetchArtifactTask('meta'))
                bash {
                  commandString = 'rake --trace osx:sign osx:upload[${EXPERIMENTAL_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
          }
        }

        stage('metadata') {
          secureEnvironmentVariables = [
            GOCD_GPG_PASSPHRASE: 'AES:7lAutKoRKMuSnh3Sbg9DeQ==:8fhND9w/8AWw6dJhmWpTcCdKSsEcOzriQNiKFZD6XtN+sJvZ65NH/QFXRNiy192+SSTKsbhOrFmw+kAKt5+MH1Erd6H54zJjpSgvJUmsJaQ=',
            AWS_ACCESS_KEY_ID: 'AES:LrDnmFW7ccFMuNzSQOUVUA==:S7wAb+ax9rKPi11h8x++3+ZjxHAX0SAGySxHUudsyh4=',
            AWS_SECRET_ACCESS_KEY: 'AES:YTpL7c+j85Su27egw84Cxg==:rVtWJySwMDMkdOGW4Md7LKkyxJc8X1kJBwXE3ebQfhJdTo7mCAn8jelLSyUAcEFI'
          ]

          jobs {
            job('generate') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                addAll(cleanTasks())
                add(fetchArtifactTask('meta'))
                bash {
                  commandString = 'rake --trace metadata:generate[${EXPERIMENTAL_DOWNLOAD_BUCKET},${UPDATE_CHECK_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
          }
        }
      }
    }

    pipeline('promote-stable-release') {
      group='go-cd'

      environmentVariables=[
        'STABLE_DOWNLOAD_BUCKET': 'ketanpkr-test-stable',
        'EXPERIMENTAL_DOWNLOAD_BUCKET':'ketanpkr-test-experimental/experimental',
        'UPDATE_CHECK_BUCKET':'ketanpkr-test-update-check',
        'ADDONS_EXPERIMENTAL_BUCKET':'ketanpkr-addon-experimental/addons/experimental' ,
        'ADDONS_STABLE_BUCKET':'ketanpkr-addon-stable/addons'
      ]

      secureEnvironmentVariables = [
              GOCD_GPG_PASSPHRASE: 'AES:7lAutKoRKMuSnh3Sbg9DeQ==:8fhND9w/8AWw6dJhmWpTcCdKSsEcOzriQNiKFZD6XtN+sJvZ65NH/QFXRNiy192+SSTKsbhOrFmw+kAKt5+MH1Erd6H54zJjpSgvJUmsJaQ=',
              AWS_ACCESS_KEY_ID: 'AES:LrDnmFW7ccFMuNzSQOUVUA==:S7wAb+ax9rKPi11h8x++3+ZjxHAX0SAGySxHUudsyh4=',
              AWS_SECRET_ACCESS_KEY: 'AES:YTpL7c+j85Su27egw84Cxg==:rVtWJySwMDMkdOGW4Md7LKkyxJc8X1kJBwXE3ebQfhJdTo7mCAn8jelLSyUAcEFI'
      ]

      materials(){
        git('codesigning') {
          url = 'https://github.com/ketan/codesigning'
          destination = "codesigning"
          blacklist = ["**/*.*", "**/*"]
        }
        git('enterprise') {
          url = 'https://gocd:cz44DJpf2muap@git.gocd.io/git/gocd-private/enterprise'
          destination = "go-enterprise"
          shallowClone="true"
          blacklist = ["**/*.*", "**/*"]
        }
        svn('signing-keys') {
          url = "https://github.com/gocd-private/signing-keys/trunk"
          username = "gocd-ci-user"
          encryptedPassword = "AES:taOvOCaXsoVwzIi+xIGLdA==:GSfhZ6KKt6MXKp/wdYYoyBQKKzbTiyDa+35kDgkEIOF75s9lzerGInbqbUM7nUKc"
          destination = "signing-keys"
        }
        dependency('code-sign') {
          pipeline = 'code-sign'
          stage = 'metadata'
        }
        dependency('go-packages') {
          pipeline = 'go-packages'
          stage = 'fetch_from_build_go_cd'
        }
        dependency('regression-pg-gauge') {
          pipeline = 'regression-pg-gauge'
          stage = 'regression'
        }
        dependency('go-addon-build') {
          pipeline = 'go-addon-build'
          stage = 'build-addons'
        }
      }

      stages{
        stage('promote-binaries') {
          jobs{
            job('promote-binaries') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                fetchDirectory {
                  pipeline = 'installers/code-sign'
                  stage = 'dist'
                  job = 'dist'
                  source = "dist/meta"
                  destination = "codesigning/src"
                }
                bash{
                  commandString='rake --trace promote:copy_binaries_from_experimental_to_stable[${EXPERIMENTAL_DOWNLOAD_BUCKET},${STABLE_DOWNLOAD_BUCKET}]'
                  workingDir='codesigning'
                }
                bash{
                  commandString='rake --trace promote:copy_addon_from_experimental_to_stable[${ADDONS_EXPERIMENTAL_BUCKET},${ADDONS_STABLE_BUCKET}]'
                  workingDir='codesigning'
                }
              }
            }
          }
        }

        stage('create-repositories') {
          jobs {
            job('apt') {
              elasticProfileId = 'ubuntu-16.04'
              tasks {
                fetchDirectory {
                  pipeline = 'installers/code-sign'
                  stage = 'dist'
                  job = 'dist'
                  source = "dist/meta"
                  destination = "codesigning/src"
                }
                bash {
                  commandString = 'rake --trace apt:createrepo[${STABLE_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }

            job('yum') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                fetchDirectory {
                  pipeline = 'installers/code-sign'
                  stage = 'dist'
                  job = 'dist'
                  source = "dist/meta"
                  destination = "codesigning/src"
                }
                bash {
                  commandString = 'rake --trace yum:createrepo[${STABLE_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
          }
        }

        stage('publish') {
          jobs{
            job('publish') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                fetchDirectory {
                  pipeline = 'installers/code-sign'
                  stage = 'dist'
                  job = 'dist'
                  source = "dist/meta"
                  destination = "codesigning/src"
                }
                bash {
                  commandString = 'rake --trace metadata:releases_json[${STABLE_DOWNLOAD_BUCKET}]'
                  workingDir = 'codesigning'
                }
                bash {
                  commandString = 'rake --trace promote:update_check_json[${EXPERIMENTAL_DOWNLOAD_BUCKET},${UPDATE_CHECK_BUCKET}]'
                  workingDir = 'codesigning'
                }
                bash {
                  commandString = 'rake --trace promote:promote_addons_metadata[${ADDONS_EXPERIMENTAL_BUCKET},${ADDONS_STABLE_BUCKET}]'
                  workingDir = 'codesigning'
                }
              }
            }
          }
        }
      }
    }
  }
}

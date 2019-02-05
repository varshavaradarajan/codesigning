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

def signArtifactTask = {String osType ->
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
      pipelines = ['code-sign']
    }
  }

  pipelines {
    pipeline('code-sign') { thisPipeline ->
      group = 'go-cd'
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

      stages { stages ->
        stage('sign') {
          secureEnvironmentVariables = [
            GOCD_GPG_PASSPHRASE: 'AES:7lAutKoRKMuSnh3Sbg9DeQ==:8fhND9w/8AWw6dJhmWpTcCdKSsEcOzriQNiKFZD6XtN+sJvZ65NH/QFXRNiy192+SSTKsbhOrFmw+kAKt5+MH1Erd6H54zJjpSgvJUmsJaQ='
          ]
          jobs {
            job('rpm') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                add(fetchArtifactTask('rpm'))
                add(signArtifactTask('rpm'))
              }
              artifacts {
                add(publishArtifactTask('rpm'))
              }
            }
            job('deb') {
              elasticProfileId = 'ubuntu-16.04-with-sudo'
              tasks {
                add(fetchArtifactTask('deb'))
                add(signArtifactTask('deb'))
              }
              artifacts {
                add(publishArtifactTask('deb'))
              }
            }
            job('zip') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks {
                add(fetchArtifactTask('zip'))
                add(signArtifactTask('zip'))
              }
              artifacts {
                add(publishArtifactTask('zip'))
              }
            }
            job('win') {
              elasticProfileId = 'window-dev-build'
              tasks {
                add(fetchArtifactTask('win'))
                add(signArtifactTask('win'))
              }

              artifacts {
                add(publishArtifactTask('win'))
              }
            }
            job('osx') {
              resources = ['mac', 'signer']
              tasks {
                add(fetchArtifactTask('osx'))
                add(signArtifactTask('osx'))
              }

              artifacts {
                add(publishArtifactTask('osx'))
              }
            }
          }
        }

        stage('metadata') {
          jobs {
            job('generate') {
              elasticProfileId = 'ecs-gocd-dev-build'
              tasks { tasks ->
                stages.first().jobs.getNames().each { jobName ->
                  tasks.fetchFile {
                    pipeline = thisPipeline.name
                    stage = stages.first().name
                    job = jobName
                    source = "dist/${jobName}/metadata.json"
                    destination = "codesigning/src/${jobName}/metadata.json"
                  }
                }

                tasks.fetchArtifact {
                    pipeline = 'installers'
                    stage = 'dist'
                    job = 'dist'
                    source = "dist/meta"
                    destination = "codesigning/src/dist"
                }

                exec {
                  commandLine = ['ls', '-alR', 'codesigning/src']
                }
              }
            }
          }
        }
      }
    }
  }
}

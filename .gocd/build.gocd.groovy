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

GoCD.script {
  environments {
    environment('gocd') {
      pipelines = ['code-sign']
    }
  }

  pipelines {
    pipeline('code-sign') {
      group = 'go-cd'
      materials() {
        git('codesigning') {
          url = 'https://github.com/ketan/codesigning'
          destination = "codesigning"
        }
        svn('signing-keys') {
          url = "https://github.com/gocd-private/signing-keys"
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
          jobs {
            ['rpm', 'deb'].collect { osType ->
              job(osType) {
                secureEnvironmentVariables = [
                  GOCD_GPG_PASSPHRASE: 'AES:7lAutKoRKMuSnh3Sbg9DeQ==:8fhND9w/8AWw6dJhmWpTcCdKSsEcOzriQNiKFZD6XtN+sJvZ65NH/QFXRNiy192+SSTKsbhOrFmw+kAKt5+MH1Erd6H54zJjpSgvJUmsJaQ='
                ]
                elasticProfileId = 'ecs-gocd-dev-build'
                tasks {
                  fetchDirectory {
                    pipeline = 'installers'
                    stage = 'dist'
                    job = 'dist'
                    source = "dist/${osType}"
                    destination = '.'
                  }
                  bash {
                    commandString = 'echo "${GOCD_GPG_PASSPHRASE}" > gpg-passphrase'
                    workingDir = 'signing-keys'
                  }
                  exec {
                    commandLine = ["ls", "-alR"]
                  }
                  exec {
                    commandLine = ["rake", "--trace", "${osType}:sign"]
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
}

sudo su -
service docker start
cd /home/ec2-user
mkdir gocd
chown 500.500 gocd
# docker run -it --rm -v$(pwd)/gnupg:/go/gnupg -v$(pwd)/codesign:/go/codesign -v$(pwd)/gocd:/go/gocd docker.gocd.io/gocddev/gocd-dev-build:centos-6-v2.0.52 bash
docker run -it --rm -v$(pwd)/gnupg:/go/gnupg -v$(pwd)/codesign:/go/codesign docker.gocd.io/gocddev/gocd-dev-build:centos-6-v2.0.52 bash

mkdir $HOME/.aws

echo '[default]
aws_access_key_id = AKIAJXM2KZCXO7T4UC5A
aws_secret_access_key = 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
' > $HOME/.aws/credentials

curl https://view:password@build.gocd.org/go/files/installers/1361/dist/1/dist/dist/rpm.zip > ~/rpm.zip
curl https://view:password@build.gocd.org/go/files/installers/1361/dist/1/dist/dist/deb.zip > ~/deb.zip

unzip -o ~/rpm.zip -d ~/
unzip -o ~/deb.zip -d ~/

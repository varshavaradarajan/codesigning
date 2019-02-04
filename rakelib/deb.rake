# make sure deps are installed using
# `apt-get install -y debsigs gnupg gnupg-agent dpkg-sig apt-utils bzip2 gzip unzip zip rake sudo`
# `echo "go ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/go`
namespace :deb do
  signing_dir = "out/deb"
  deb_source_dir = 'src/deb'
  gpg_signing_id = '0xD8843F288816C449'

  desc "sign deb binaries"
  task :sign => ['gpg:setup'] do
    if Dir["#{deb_source_dir}/*.deb"].empty?
      raise "Unable to find any binaries in #{deb_source_dir}"
    end

    rm_rf signing_dir
    mkdir_p signing_dir
    Dir["#{deb_source_dir}/*.deb"].each do |f|
      cp f, "#{signing_dir}"
    end

    cd signing_dir do
      Dir["*.deb"].each do |f|
        sh("dpkg-sig --verbose --sign builder -k '#{gpg_signing_id}' '#{f}'")
      end
    end

    sh("gpg --armor --output GPG-KEY-GOCD-#{Process.pid} --export #{gpg_signing_id}")
    sh("sudo apt-key add GPG-KEY-GOCD-#{Process.pid}")
    rm "GPG-KEY-GOCD-#{Process.pid}"

    Dir["#{signing_dir}/*.deb"].each do |f|
      sh("dpkg-sig --verbose --verify '#{f}'")
    end
  end
end

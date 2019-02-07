# make sure deps are installed using
# `apt-get install -y debsigs gnupg gnupg-agent dpkg-sig apt-utils bzip2 gzip unzip zip rake sudo`
# `echo "go ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/go`
namespace :deb do
  signing_dir = "out/deb"
  deb_source_dir = 'src/deb'
  meta_source_dir = 'src/meta'

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
        sh("dpkg-sig --verbose --sign builder -k '#{GPG_SIGNING_ID}' '#{f}'")
      end
    end

    sh("gpg --armor --output GPG-KEY-GOCD-#{Process.pid} --export #{GPG_SIGNING_ID}")
    sh("sudo apt-key add GPG-KEY-GOCD-#{Process.pid}")
    rm "GPG-KEY-GOCD-#{Process.pid}"

    Dir["#{signing_dir}/*.deb"].each do |f|
      sh("dpkg-sig --verbose --verify '#{f}'")
    end

    generate_metadata_for_single_dir signing_dir, '*.deb', :deb
  end

  desc "upload the deb binaries, after signing the binaries"
  task :upload => :sign do
    go_full_version = JSON.parse(File.read("#{meta_source_dir}/version.json"))['go_full_version']

    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} --acl public-read --cache-control 'max-age=31536000' #{signing_dir} s3://#{S3_DOWNLOAD_BUCKET_BASE_URL}/binaries/#{go_full_version}/deb")
  end
end

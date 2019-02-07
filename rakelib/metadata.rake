require 'json'
require 'time'
require 'base64'
require 'openssl'

namespace :metadata do
  meta_source_dir = 'src/meta'
  out_dir = 'out/meta'
  desc "aggregate metadata from all dirs"
  task :generate => ['gpg:setup', :unlock_update_check_credentials] do
    release_time = Time.now.utc
    metadata = JSON.parse(File.read("#{meta_source_dir}/version.json"))
    metadata.merge!(release_time_readable: release_time.xmlschema, release_time: release_time.to_i)
    go_full_version = metadata['go_full_version']

    rm_rf out_dir
    mkdir_p out_dir

    # fetch all metadata from s3
    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} --delete --exclude='*' --include '*.json' s3://#{S3_BASE_URL}/binaries/#{go_full_version} out")

    %w(deb rpm osx win generic).each do |dir|
      json_files = Dir["out/#{dir}/*.json"]
      raise "Did not find any JSON files under `out/#{dir}`" if json_files.empty?

      json_files.each do |json_file|
        metadata.merge!(JSON.parse(File.read(json_file)))
      end
    end
    open('out/metadata.json', 'w') {|f| f.write(JSON.generate(metadata)) }
    sh("aws s3 cp #{'--no-progress' unless $stdin.tty?} out/metadata.json s3://#{S3_BASE_URL}/binaries/#{go_full_version}/ --acl public-read --cache-control 'max-age=31536000'")

    # generate the update check json
    message = JSON.generate({
      'latest-version' => go_full_version,
      'release-time'   => Time.now.utc.xmlschema
    })

    digest            = OpenSSL::Digest::SHA512.new
    private_key       = OpenSSL::PKey::RSA.new(File.read('../signing-keys/update-check-signing-keys/subordinate-private-key.pem'), File.read('../signing-keys/update-check-signing-keys/subordinate-private-key-passphrase').strip)
    message_signature = Base64.encode64(private_key.sign(digest, message))

    open('out/latest.json', 'w') do |f|
      f.puts(JSON.generate({
        message:                      message,
        message_signature:            message_signature,
        signing_public_key:           File.read('../signing-keys/update-check-signing-keys/subordinate-public-key.pem'),
        signing_public_key_signature: File.read('../signing-keys/update-check-signing-keys/subordinate-public-key-digest')
      }))
    end

    sh("aws s3 cp #{'--no-progress' unless $stdin.tty?} out/latest.json s3://#{S3_BASE_URL}/binaries/#{go_full_version}/ --acl public-read --cache-control 'max-age=31536000'")
  end

  task :unlock_update_check_credentials do
    cd '../signing-keys/update-check-signing-keys' do
      open('gpg-passphrase', 'w') {|f| f.write(ENV['GOCD_GPG_PASSPHRASE'])}
      Dir['*.gpg'].each do |f|
        sh("gpg --yes --quiet --batch --passphrase-file gpg-passphrase --output '#{f.gsub(/.gpg$/, '''')}' '#{f}'")
      end
    end
  end
end

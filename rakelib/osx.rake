require 'securerandom'

# make sure deps are installed using
namespace :osx do
  signing_dir     = "out/osx"
  osx_source_dir  = 'src/osx'
  meta_source_dir = 'src/meta'

  # assumes the following:
  # - File `../signing-keys/codesign.keychain.password.gpg` containing the encrypted keychain passphrase
  # - environment variable `GOCD_GPG_PASSPHRASE` containing the passphrase to decrypt the said key
  desc "setup code signing keys"
  task :setup do
    cd '../signing-keys' do
      open('gpg-passphrase', 'w') {|f| f.write(ENV['GOCD_GPG_PASSPHRASE'])}
      sh("gpg --batch --yes --passphrase-file gpg-passphrase --output codesign.keychain.password codesign.keychain.password.gpg")
    end
  end

  desc "sign a single osx binary"
  task :sign_single_binary, [:path, :dest_archive] do |task, args|
    path = args[:path]
    dest_archive = File.expand_path(args[:dest_archive] || "#{File.basename(path)}.zip")

    fail "You must specify a path to sign" if path.nil?
    fail "Path #{path} does not exists"  unless File.exist?(path)
    fail "Path must be a file, not a directory" if File.directory?(path)

    dest_dir = File.dirname(dest_archive)
    mkdir_p dest_dir # don't ensure_clean_dir in case it points to a parent directory
    work_dir = ensure_clean_dir(File.join("tmp", SecureRandom.hex))
    signed_file = File.join(work_dir, File.basename(path))

    cp path, signed_file

    keychain_path = File.expand_path(File.exist?("~/Library/Keychains/codesign.keychain-db") ? "~/Library/Keychains/codesign.keychain-db" : "~/Library/Keychains/codesign.keychain")
    keychain_passwd = File.read("../signing-keys/codesign.keychain.password")

    run("Unlocking keychain", "security unlock-keychain -p #{keychain_passwd.inspect} #{keychain_path.inspect}") do
      begin
        run("Codesigning binary #{signed_file.inspect}", "codesign --force --verify --verbose --sign \"Developer ID Application: ThoughtWorks (LL62P32G5C)\" #{signed_file.inspect}")
      ensure
        run("Locking keychain again", "security lock-keychain #{keychain_path.inspect}")
      end
    end

    File.utime(0, 0, signed_file)

    cd work_dir do
      sh("zip -q -r #{dest_archive} .")
    end

    generate_metadata_for_single_dir dest_dir, '*.zip', :osx
  end

  desc 'sign osx zip instead of binaries'
  task :sign_as_zip => ['gpg:setup'] do
    if Dir["#{osx_source_dir}/*.zip"].empty?
      raise "Unable to find any binaries in #{osx_source_dir}"
    end

    rm_rf signing_dir
    mkdir_p signing_dir
    Dir["#{osx_source_dir}/*.zip"].each do |f|
      cp f, "#{signing_dir}"
    end

    cd signing_dir do
      Dir["*.zip"].each do |f|
        sh("gpg --default-key '#{GPG_SIGNING_ID}' --armor --detach-sign --sign --output '#{f}.asc' '#{f}'")
        sh("gpg --default-key '#{GPG_SIGNING_ID}' --verify '#{f}.asc'")
      end
    end

    rm_rf 'tmp'

    generate_metadata_for_single_dir signing_dir, '*.zip', :osx
  end

  desc "upload the osx binaries, after signing the binaries"
  task :upload, [:bucket_url] => :sign_as_zip do |t, args|
    bucket_url = args[:bucket_url]

    raise "Please specify bucket url" unless bucket_url

    go_full_version = JSON.parse(File.read("#{meta_source_dir}/version.json"))['go_full_version']

    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} --acl public-read --cache-control 'max-age=31536000' #{signing_dir} s3://#{bucket_url}/binaries/#{go_full_version}/osx")
  end

  def ensure_clean_dir(directory)
    directory.tap do |d|
      rm_rf d
      mkdir_p d
    end
  end

  def run(label, cmd, &block)
    puts label
    sh(cmd) do |ok, res|
      fail "Error when: #{label}: #{res}" unless ok
      block.call if block_given?
    end
  end
end

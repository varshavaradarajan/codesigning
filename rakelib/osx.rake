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

  desc "sign osx binaries"
  task :sign, [:path] => [:setup] do |task, args|
    path = args[:path] || osx_source_dir

    rm_rf signing_dir
    mkdir_p signing_dir

    scratch_dir = "tmp/osx"

    if File.directory?(path)
      if Dir["#{path}/*.zip"].empty?
        raise "Unable to find any binaries in #{path}"
      end

      Dir["#{path}/*.zip"].each do |f|
        sign_binaries_within_zip(f, signing_dir, scratch_dir)
      end
    else
      sign_binaries_within_zip(path, signing_dir, scratch_dir)
    end

    rm_rf 'tmp'

    generate_metadata_for_single_dir signing_dir, '*.zip', :osx
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

  def sign_binaries_within_zip(zipfile, out_dir, scratch_dir="tmp/osx")
    rm_rf scratch_dir
    mkdir_p scratch_dir

    work_dir = [scratch_dir, SecureRandom.hex].join("/")
    out_dir = File.expand_path out_dir

    run("Unpacking zip #{zipfile}", "unzip -q -o #{zipfile.inspect} -d #{work_dir}")
    glob = "#{work_dir}/**/*"

    keychain_path = File.expand_path(File.exist?("~/Library/Keychains/codesign.keychain-db") ? "~/Library/Keychains/codesign.keychain-db" : "~/Library/Keychains/codesign.keychain")
    keychain_passwd = File.read("../signing-keys/codesign.keychain.password")

    run("Unlocking keychain", "security unlock-keychain -p #{keychain_passwd.inspect} #{keychain_path.inspect}") do
      Dir.glob(glob) do |f|
        run("Codesigning binary #{f.inspect}", "codesign --force --verify --verbose --sign \"Developer ID Application: ThoughtWorks (LL62P32G5C)\" #{f.inspect}") unless File.directory?(f)
      end
      run("Locking keychain again", "security lock-keychain #{keychain_path.inspect}")
    end

    Dir["#{work_dir}/**/*"].each do |f|
      File.utime(0, 0, f)
    end

    Dir["#{work_dir}/**/*.*"].each do |f|
      File.utime(0, 0, f)
    end

    cd work_dir do
      sh("zip -q -r #{out_dir}/#{File.basename(zipfile)} .")
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

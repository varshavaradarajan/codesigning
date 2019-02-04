# make sure deps are installed using
# `choco install gpg4win`
namespace :win do
  signing_dir = "out/win"
  win_source_dir = 'src/win'
  gpg_signing_id = '0xD8843F288816C449'

  # assumes the following:
  # - File `../signing-keys/windows-code-sign.p12.gpg` containing the encrypted p12/pfx codesigning key
  # - environment variable `GOCD_GPG_PASSPHRASE` containing the passphrase to decrypt the said key
  desc "setup code signing keys"
  task :setup do
    cd '../signing-keys' do
      open('gpg-passphrase', 'w') {|f| f.write(ENV['GOCD_GPG_PASSPHRASE'])}
      sh("gpg --quiet --batch --passphrase-file gpg-passphrase --output windows-code-sign.p12 windows-code-sign.p12.gpg")
      sh("certutil.exe -addstore Root windows-code-sign.p12")
    end
  end

  desc "sign win binaries"
  task :sign => ['setup'] do
    if Dir["#{win_source_dir}/*.exe"].empty?
      raise "Unable to find any binaries in #{win_source_dir}"
    end

    rm_rf signing_dir
    mkdir_p signing_dir
    Dir["#{win_source_dir}/*.exe"].each do |f|
      cp f, "#{signing_dir}"
    end

    cd signing_dir do
      Dir["#{signing_dir}/*.exe"].each do |f|
        sh("dpkg-sig --verbose --sign builder -k '#{gpg_signing_id}' '#{f}'")
      end
      sh("gpg --armor --output GPG-KEY-GOCD-#{Process.pid} --export #{gpg_signing_id}")
      sh("sudo apt-key add GPG-KEY-GOCD-#{Process.pid}")
      rm "GPG-KEY-GOCD-#{Process.pid}"
      Dir["#{signing_dir}/*.win"].each do |f|
        sh("dpkg-sig --verbose --verify '#{f}'")
      end
    end
  end
end

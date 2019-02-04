# make sure deps are installed using
# `choco install gpg4win windows-sdk-8.0`
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
    end

    sh("choco install windows-sdk-8.1 --yes --no-progress")
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

    Dir["#{signing_dir}/*.exe"].each do |f|
      sh("signtool sign /debug /f ../signing-keys/windows-code-sign.p12 /v /t http://timestamp.digicert.com /a '#{f}'")
      sh("signtool sign /debug /f ../signing-keys/windows-code-sign.p12 /v /tr http://timestamp.digicert.com /a /fd sha256 /td sha256 /as '#{f}'")

      sh("signtool verify /debug /f ../signing-keys/windows-code-sign.p12 /v /a /pa /hash sha1 '#{f}'")
      sh("signtool verify /debug /f ../signing-keys/windows-code-sign.p12 /v /a /pa /hash sha256 '#{f}'")
    end
  end
end

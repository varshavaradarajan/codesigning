namespace :gpg do
  desc "import gpg keys into a GPG database"
  task :setup do
    # assumes the following:
    # - File `../signing-keys/gpg-keys.pem.gpg` containing the encrypted gpg key
    # - environment variable `GOCD_GPG_PASSPHRASE` containing the passphrase to decrypt the said GPG key
    ENV['GNUPGHOME'] = File.expand_path('~/.code-signing-keys')
    rm_rf ENV['GNUPGHOME']
    mkdir_p ENV['GNUPGHOME']
    chmod 0700, ENV['GNUPGHOME']
    cd '../signing-keys' do
      fifo_file = "/tmp/gpg-passphrase-#{Process.pid}"
      begin
        File.mkfifo("/tmp/gpg-passphrase-#{Process.pid}", 0600)
        open(fifo_file, 'w+') {|f| f.write(ENV['GOCD_GPG_PASSPHRASE'])}
        sh('gpg --quiet --batch --passphrase-file gpg-passphrase --output - gpg-keys.pem.gpg | gpg --import --batch --quiet')
      ensure
        rm_rf fifo_file
      end
    end
  end
end

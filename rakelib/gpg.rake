namespace :gpg do
  desc "import gpg keys into a GPG database"
  task :setup do
    # assumes the following files:
    # - `../signing-keys/gpg-passphrase`
    # - `../signing-keys/gpg-keys.pem.gpg`
    ENV['GNUPGHOME'] = File.expand_path('~/.code-signing-keys')
    rm_rf ENV['GNUPGHOME']
    mkdir_p ENV['GNUPGHOME']
    chmod 0700, ENV['GNUPGHOME']
    cd '../signing-keys' do
      sh('gpg --quiet --batch --passphrase-file gpg-passphrase --output - gpg-keys.pem.gpg | gpg --import --batch --quiet')
    end
  end
end

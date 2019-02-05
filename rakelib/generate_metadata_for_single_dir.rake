def generate_metadata_for_single_dir(signing_dir, glob, metadata_key)
  cd signing_dir do
    metadata = {}
    Dir[glob].each do |each_file|
      file_contents = File.read(each_file)
      component = each_file =~ /go-server/ ? 'server' : 'agent'
      checksums = {
        md5sum:    Digest::MD5.hexdigest(file_contents),
        sha1sum:   Digest::SHA1.hexdigest(file_contents),
        sha256sum: Digest::SHA256.hexdigest(file_contents),
        sha512sum: Digest::SHA512.hexdigest(file_contents),
        file: "zip/#{each_file}",
      }

      metadata[component] = checksums


      checksums.each do |k, v|
        open("#{each_file}.#{k}", 'w') {|f| f.puts([v, File.basename(each_file)].join('  '))}
      end
    end

    open('metadata.json', 'w') {|f| f.puts(JSON.pretty_generate(metadata_key => metadata))}
  end
end
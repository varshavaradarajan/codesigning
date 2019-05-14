def generate_metadata_for_single_dir(signing_dir, glob, metadata_key)
  cd signing_dir do
    metadata = {}
    Dir[glob].each do |each_file|
      component = each_file =~ /go-server/ ? 'server' : 'agent'
      checksums = {
        md5sum:    Digest::MD5.file(each_file).hexdigest,
        sha1sum:   Digest::SHA1.file(each_file).hexdigest,
        sha256sum: Digest::SHA256.file(each_file).hexdigest,
        sha512sum: Digest::SHA512.file(each_file).hexdigest,
        file: "#{metadata_key}/#{each_file}",
      }

      metadata[component] = checksums

      checksums.each do |k, v|
        next unless k =~ /sum$/
        open("#{each_file}.#{k}", 'w') {|f| f.puts([v, File.basename(each_file)].join('  '))}
      end
    end

    json = {metadata_key => metadata}

    $stderr.puts "Generated checksums: #{JSON.pretty_generate(json)}"
    open('metadata.json', 'w') {|f| f.puts(JSON.generate(json))}
  end
end
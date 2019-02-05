require 'json'

namespace :zip do
  signing_dir = "out/zip"
  zip_source_dir = 'src/zip'
  gpg_signing_id = '0xD8843F288816C449'

  desc "sign zip binaries"
  task :sign => ['gpg:setup'] do
    if Dir["#{zip_source_dir}/*.zip"].empty?
      raise "Unable to find any binaries in #{zip_source_dir}"
    end

    rm_rf signing_dir
    mkdir_p signing_dir
    Dir["#{zip_source_dir}/*.zip"].each do |f|
      cp f, "#{signing_dir}"
    end

    cd signing_dir do
      Dir["*.zip"].each do |f|
        sh("gpg --default-key '#{gpg_signing_id}' --armor --detach-sign --sign --output '#{f}.asc' '#{f}'")
        sh("gpg --default-key '#{gpg_signing_id}' --verify '#{f}.asc'")
      end
    end

    generate_metadata_for_single_dir signing_dir, "*.zip", :generic
  end
end

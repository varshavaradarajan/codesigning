require 'json'
require 'pathname'
require_relative '../lib/addon_metadata'

desc "prepare addons for upload"
task :prepare_addons_for_upload, [:bucket_url, :full_version] do |t, args|
  bucket_url = args[:bucket_url]
  raise "bucket url is needed" unless bucket_url

  full_version = args[:full_version]
  raise "full version is needed" unless full_version

  target_dir = Pathname.new('target')
  addons_dir = target_dir.join('s3', full_version)
  rm_rf addons_dir
  mkdir_p addons_dir

  Dir['src/pkg_for_upload/*.jar'].each do |addon|
    cp addon, addons_dir
  end

  cd addons_dir do
    sh('md5sum    *.jar > addons-md5.checksum')
    sh('sha1sum   *.jar > addons-sha1.checksum')
    sh('sha256sum *.jar > addons-sha256.checksum')
    sh('sha512sum *.jar > addons-sha512.checksum')
  end

  path_without_bucket_name = get_path_inside_addon_bucket(bucket_url)

  pg_addon_metadata = AddonMetadata.new(
      addon_file_s3_parent:  "#{path_without_bucket_name}/#{full_version}",
      metadata_full_s3_path: "s3://#{bucket_url}/go-postgresql.json",
      version:               full_version,
      prefix:                'pg'
  )

  bc_addon_metadata = AddonMetadata.new(
      addon_file_s3_parent:  "#{path_without_bucket_name}/#{full_version}",
      metadata_full_s3_path: "s3://#{bucket_url}/go-business-continuity.json",
      version:               full_version,
      prefix:                'bc'
  )

  pg_metadata_file = pg_addon_metadata.create(Dir[addons_dir.join('go-postgresql*.jar')].first)
  pg_addon_metadata.append_to_existing(JSON.parse(File.read(pg_metadata_file)))

  bc_metadata_file = bc_addon_metadata.create(Dir[addons_dir.join('go-business-continuity*.jar')].first)
  bc_addon_metadata.append_to_existing(JSON.parse(File.read(bc_metadata_file)))
end

desc "upload addon artifacts to bucket url"
task :upload, [:bucket_url, :full_version] do |t, args|
  bucket_url = args[:bucket_url]
  raise "bucket url is needed" unless bucket_url

  full_version = args[:full_version]
  raise "full version is needed" unless full_version

  target_dir               = Pathname.new('target')
  addons_dir               = target_dir.join('s3', full_version)
  path_without_bucket_name = get_path_inside_addon_bucket(bucket_url)

  pg_addon_metadata = AddonMetadata.new(
      addon_file_s3_parent:  "#{path_without_bucket_name}/#{full_version}",
      metadata_full_s3_path: "s3://#{bucket_url}/go-postgresql.json",
      version:               full_version,
      prefix:                'pg'
  )

  bc_addon_metadata = AddonMetadata.new(
      addon_file_s3_parent:  "#{path_without_bucket_name}/#{full_version}",
      metadata_full_s3_path: "s3://#{bucket_url}/go-business-continuity.json",
      version:               full_version,
      prefix:                'bc'
  )

  sh("aws s3 sync #{addons_dir} s3://#{bucket_url}/#{full_version} --acl private --cache-control 'max-age=31536000'")
  pg_addon_metadata.upload_combined_metadata_file
  bc_addon_metadata.upload_combined_metadata_file
end

task :fetch_and_upload_addons, [:bucket_url, :full_version] => [:prepare_addons_for_upload, :upload]
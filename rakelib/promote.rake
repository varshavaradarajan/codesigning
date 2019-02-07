# desc "task to promote artifacts to release"
# task :promote do
#   go_full_version = JSON.parse(File.read("#{meta_source_dir}/version.json"))['go_full_version']

#   sh("aws s3 sync s3://#{S3_EXPERIMENTAL_DOWNLOAD_BUCKET_BASE_URL}/bianries/#{go_full_version} s3://#{S3_STABLE_DOWNLOAD_BUCKET_BASE_URL}/binaries/#{go_full_version} --acl public-read --cache-control 'max-age=31536000'")

# end


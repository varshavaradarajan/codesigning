require 'json'
require 'pathname'

task :sync_experimental_stable, [:bucket_url, :stable_bucket_url] do |t, args|
  bucket_url = args[:bucket_url]
  raise "Please specify experimental bucket url" unless bucket_url

  stable_bucket_url = args[:stable_bucket_url]
  raise "Please specify stable bucket url" unless stable_bucket_url

  meta_source_dir = 'src/meta'
  go_full_version = JSON.parse(File.read("#{meta_source_dir}/version.json"))['go_full_version']

  sh("aws s3 sync s3://#{bucket_url}/binaries/#{go_full_version} s3://#{stable_bucket_url}/binaries/#{go_full_version} --acl public-read --cache-control 'max-age=31536000'")
  # sync adds ons

end

desc "create repository"
task :create_repository, [:bucket_url, :stable_bucket_url] => [:sync_experimental_stable, "apt:createrepo", "yum:createrepo"]

desc "task to promote artifacts to release"
task :promote, [:bucket_url, :stable_bucket_url, :update_bucket_url] => [:create_repository] do |t, args|
  experimental_bucket_url = args[:bucket_url]
  raise "Please specify experimental bucket url" unless experimental_bucket_url

  update_bucket_url = args[:update_bucket_url]
  raise "Please specify update bucket url" unless update_bucket_url

  meta_source_dir = 'src/meta'
  go_full_version = JSON.parse(File.read("#{meta_source_dir}/version.json"))['go_full_version']

  sh("aws s3 cp s3://#{update_bucket_url}/channels/supported/latest.json s3://#{update_bucket_url}/channels/supported/latest.previous.json --cache-control 'max-age=600' --acl public-read")

  sh("aws s3 cp s3://#{experimental_bucket_url}/binaries/#{go_full_version}/latest.json /tmp/latest.json")

  sh("aws s3 cp /tmp/latest.json s3://#{update_bucket_url}/channels/supported/latest.json --cache-control 'max-age=600' --acl public-read")
  sh("aws s3 cp /tmp/latest.json s3://#{update_bucket_url}/channels/supported/latest-#{go_full_version}.json --cache-control 'max-age=600' --acl public-read")
  sh("rm /tmp/latest.json")
end

desc "create releases.json"
task :create_releases_json, [:bucket_url] do |t, args|
  experimental_bucket_url = args[:bucket_url]
  raise "Please specify experimental bucket url" unless experimental_bucket_url

  target_dir = Pathname.new('target')

  sh("aws s3 sync --exclude='*' --include '**/metadata.json' s3://#{experimental_bucket_url} #{target_dir.join('repo')}")

  json = Dir["#{target_dir.join('repo', 'out', 'metadata.json')}"].sort.collect {|file|
    JSON.parse(File.read(file))
  }

  open(target_dir.join('repo', 'releases.json'), 'w') do |file|
    file.write(JSON.generate(json))
  end
end

desc "upload the repository metadata"
task :upload, [:bucket_url] do |t, args|
  experimental_bucket_url = args[:bucket_url]
  raise "Please specify experimental bucket url" unless experimental_bucket_url

  target_dir = Pathname.new('target')
  %w(GOCD-GPG-KEY.asc InRelease Packages Packages.bz2 Packages.gz Release Release.gpg releases.json).each do |file|
    # low cache ttl
    sh("aws s3 cp #{target_dir.join('repo', file)} s3://#{experimental_bucket_url}/#{file} --acl public-read --cache-control 'max-age=600'")
  end

  # yum repomd.xml (low cache ttl)
  sh("aws s3 sync #{target_dir.join('repo', 'repodata')} s3://#{experimental_bucket_url}/repodata/ --delete --acl public-read --cache-control 'max-age=600' --exclude '*' --include 'repomd.xml*'")

  # rest of the yum metadata (high cache ttl)
  sh("aws s3 sync #{target_dir.join('repo', 'repodata')} s3://#{experimental_bucket_url}/repodata/ --delete --acl public-read --cache-control 'max-age=31536000'")

  # yum repoview (low cache ttl)
  sh("aws s3 sync #{target_dir.join('repo', 'repoview')} s3://#{experimental_bucket_url}/repoview/ --delete --acl public-read --cache-control 'max-age=600'")

end

task :default, [:bucket_url, :stable_bucket_url, :update_bucket_url] => [:promote, :create_releases_json, :upload]
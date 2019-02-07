#!/usr/bin/env ruby

require 'json'
require 'pathname'

target_dir = Pathname.new('target')

desc "create releases.json file"
task :create_releases_json, [:stable_bucket_url] do |t, args|
  stable_bucket_url = args[:stable_bucket_url]
  raise "Please specify stable bucket url" unless stable_bucket_url

  sh("aws s3 sync --exclude='*' --include '**/metadata.json' s3://#{stable_bucket_url} #{target_dir.join('repo')}")

  json = Dir["#{target_dir.join('repo', '**', '*', 'metadata.json')}"].sort.collect do |file|
    JSON.parse(File.read(file))
  end

  open(target_dir.join('repo', 'releases.json'), 'w') do |file|
    file.puts(JSON.generate(json))
  end
end

desc "upload the repository metadata"
task :upload, [:stable_bucket_url] do |t, args|
  stable_bucket_url = args[:stable_bucket_url]
  raise "Please specify stable bucket url" unless stable_bucket_url

  %w(GOCD-GPG-KEY.asc InRelease Packages Packages.bz2 Packages.gz Release Release.gpg releases.json).each do |item|
    # low cache ttl
    sh("aws s3 cp #{target_dir.join('repo', item)} s3://#{stable_bucket_url}/#{item} --acl public-read --cache-control 'max-age=600'")
  end

  # yum repomd.xml (low cache ttl)
  sh("aws s3 sync #{target_dir.join('repo', 'repodata')} s3://#{stable_bucket_url}/repodata/ --delete --acl public-read --cache-control 'max-age=600' --exclude '*' --include 'repomd.xml*'")

  # rest of the yum metadata (high cache ttl)
  sh("aws s3 sync #{target_dir.join('repo', 'repodata')} s3://#{stable_bucket_url}/repodata/ --delete --acl public-read --cache-control 'max-age=31536000'")

  # yum repoview (low cache ttl)
  sh("aws s3 sync #{target_dir.join('repo', 'repoview')} s3://#{stable_bucket_url}/repoview/ --delete --acl public-read --cache-control 'max-age=600'")
end

task :default, [:stable_bucket_url] => [:create_releases_json, :upload]
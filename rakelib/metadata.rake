require 'json'

namespace :metadata do
  desc "aggregate metadata from all dirs"
  task :generate do
    metadata = {}
    %w(meta deb rpm osx win zip version).each do |dir|
      metadata.merge!(JSON.parse(File.read(Dir["src/#{dir}/*.json"])))
    end
    p metadata
  end
end
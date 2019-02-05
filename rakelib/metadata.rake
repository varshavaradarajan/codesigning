require 'json'

namespace :metadata do
  desc "aggregate metadata from all dirs"
  task :generate do
    metadata = {}
    %w(meta deb rpm osx win zip version).each do |dir|
      Dir["src/#{dir}/*.json"].each do |json_file|
        metadata.merge!(JSON.parse(File.read(json_file)))
      end
    end
    open('src/metadata.json', 'w') {|f| f.write(JSON.generate(metadata)) }
  end
end
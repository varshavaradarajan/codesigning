require 'json'

desc "Upload all docker images to dockerhub"
task :upload_experimental_docker_images do
  token = ENV["DOCKERHUB_TOKEN"] || (raise "Environment variable DOCKERHUB_TOKEN is not specified")

  mkdir_p "#{Dir.home}/.docker"
  open("#{Dir.home}/.docker/config.json", "w") do |f|
    f.write({:auths => {"https://index.docker.io/v1/" => {:auth => token}}}.to_json)
  end

  %w[agent server].each do |type|
    manifest_files = Dir["docker-#{type}/manifest.json"]

    if manifest_files.length != 1
      raise "Found #{manifest_files.size} instead of 1."
    end

    manifest_files.each {|manifest|
      metadata = JSON.parse(File.read(manifest))
      org      = ENV['EXP_ORG'] || 'gocdexperimental'

      metadata.each {|image|
        puts image
        sh("cat docker-#{type}/#{image["file"]} | gunzip | docker load -q")

        sh("docker tag #{image["imageName"]}:#{image["tag"]} #{org}/gocd-#{type}:#{image["tag"]}")
        sh("docker push #{org}/gocd-#{type}:#{image["tag"]}")

        sh("docker rmi #{image["imageName"]}:#{image["tag"]}")
      }
    }
  end

end
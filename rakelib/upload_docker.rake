require 'json'

namespace :docker do

  def push_to_dockerhub(image_name, image_tag, exp = true)
    experimental_org = ENV['EXP_DOCKERHUB_ORG'] || 'gocdexperimental'
    stable_org       = ENV['STABLE_DOCKERHUB_ORG'] || 'gocd'

    org = exp ? experimental_org : stable_org
    sh("docker tag #{image_name} #{org}/#{image_tag}")

    sh("docker push #{org}/#{image_tag}")

    sh("docker rmi #{image_name}")
  end

  task :dockerhub_login do
    token = ENV["DOCKERHUB_TOKEN"] || (raise "Environment variable DOCKERHUB_TOKEN is not specified")

    mkdir_p "#{Dir.home}/.docker"
    open("#{Dir.home}/.docker/config.json", "w") do |f|
      f.write({:auths => {"https://index.docker.io/v1/" => {:auth => token}}}.to_json)
    end

  end

  desc "Upload all docker images to dockerhub"
  task :upload_experimental_docker_images => :dockerhub_login do

    %w[agent server].each do |type|
      manifest_files = Dir["docker-#{type}/manifest.json"]

      if manifest_files.length != 1
        raise "Found #{manifest_files.size} instead of 1."
      end

      manifest_files.each {|manifest|
        metadata = JSON.parse(File.read(manifest))

        metadata.each {|image|
          sh("cat docker-#{type}/#{image["file"]} | gunzip | docker load -q")

          image_name = "#{image["imageName"]}:#{image["tag"]}"
          image_tag  = "gocd-#{type}:#{image["tag"]}"

          push_to_dockerhub(image_name, image_tag, true)
        }
      }
    end

  end

  desc 'Publish docker images to hub'
  task :publish_docker_images => :dockerhub_login do
    %w[agent server].each do |type|
      manifest_files = Dir["docker-#{type}/manifest.json"]

      if manifest_files.length != 1
        raise "Found #{manifest_files.size} instead of 1."
      end

      manifest_files.each {|manifest|
        metadata = JSON.parse(File.read(manifest))

        metadata.each {|image|
          sh("cat docker-#{type}/#{image["file"]} | gunzip | docker load -q")

          image_name = "#{image["imageName"]}:#{image["tag"]}"
          image_tag  = "gocd-#{type}:#{image["tag"]}"

          push_to_dockerhub(image_name, image_tag, false)
        }
      }
    end
  end

end

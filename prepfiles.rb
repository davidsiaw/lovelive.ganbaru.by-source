require 'yaml'
File.write("credentials.json", ENV['CREDENTIALS'])
File.write("token.yaml", {"default"=>ENV['TOKEN']}.to_yaml)

#! /usr/bin/env ruby
#
require 'cli_utils'
require 'json'
require 'yaml'
require 'fileutils'

def generate_command
  @cu = CliUtils.new(commands_path)

  init_config unless File.exist?(config_path)
  @config = YAML.load(File.open(config_path,'r').read)

  key = (@config['defaults'] || {})['api_key']
  ($stderr.puts "No key specified in #{config_path}"; exit 1) unless key

  (eval @cu.eval; exit) if @cu.eval

  com = @cu.commands[@cu.command]
  uri = "curl -s -S '#{com['webService']}#{build_query}&key=#{key}'"
end

def build_query
  query = @cu.required.map{|k,v| "#{k}=#{v}"}.join('&')
  query = '?' << query if query
  query
end

def commands_path
  return @commands_path if @commands_path
  # this location is a bit weird if you want to pull,
  # as the file commands.json is updated on update-commands
  # git checkout .; git pull; ./cb-cli.rb uc
  # should work fine, though
  @commands_path = File.join(File.dirname(follow_if_link(__FILE__)), 'src', 'commands.json')
end

def cache_path
  return @cache_path if @cache_path
  @cache_path = File.join(File.dirname(follow_if_link(__FILE__)), 'cache')
end

def generate_commands
  datasets.map{|d|
    vintage = d['c_vintage']
    long = d['c_dataset']
    long = (long << vintage) if vintage
    d['long'] = long.join('-')
    d['required'] = ['get', 'for']
    d
  }
end

def cb_directory
  File.join(ENV['HOME'],'.cb-cli')
end

def config_path
  File.join(cb_directory,'cb-config')
end

def init_config
  FileUtils.mkdir_p(cb_directory)
  puts "Api Key:\n"
  key = $stdin.gets.chomp

conf=<<Conf
defaults:
  api_key: #{key}
Conf

  File.open(config_path,'w',0600){|f| f.puts(conf)}
end

def refresh_cache
  threads = []
  datasets.each{|d|
    dir = File.join(cache_path,d['identifier'])
    FileUtils.mkdir_p(dir)

    geo_uri = d['c_geographyLink']
    geo_fp = File.join(dir,'geography.json')

    var_uri = d['c_variablesLink']
    var_fp = File.join(dir,'variables.json')

    threads << Thread.new{`curl -o #{geo_fp} -s -S #{geo_uri}`; "created #{geo_fp}"}
    threads << Thread.new{`curl -o #{var_fp} -s -S #{var_uri}`; "created #{var_fp}"}
  }

  threads.each{|t| t.join; puts t.value}
end

def datasets
  return @datasets if @datasets

  datasets_uri = 'http://api.census.gov/data.json'
  @datasets = JSON.parse(`curl -s -S #{datasets_uri}`)
end

def p(arg)
  puts arg.inspect
end

def follow_if_link(path, depth=5)
  if File.symlink?(path)
    if depth > 0
      path = follow_if_link(File.readlink(path), depth - 1)
    else
      $stderr.puts("Symlink depth too great")
      exit 1
    end
  end

  path
end

### EVAL COMMANDS ###############################################################
def list_datasets
  puts JSON.pretty_generate(datasets)
end

def list_commands
  #TODO print usage, so expose in cli_utils
  puts JSON.pretty_generate(@cu.commands.map{|k, v| v['long']}.uniq)
end

def describe_command
  c_arg = @cu.required['command']
  c = @cu.commands[c_arg]

  ($stderr.puts "Command not found: #{c_arg}"; exit 1) unless c
  ($stderr.puts "No description for command: #{c_arg}"; exit 1) unless c['description']

  puts c['description']
end

def edit_config
  Kernel.exec("#{ENV['EDITOR'] || 'vim'} #{config_path}")
end

def list_variables
  c_arg = @cu.required['command']
  c = @cu.commands[c_arg]

  ($stderr.puts "Command not found: #{c_arg}"; exit 1) unless c
  ($stderr.puts "No variables found for command: #{c_arg}"; exit 1) unless c['identifier']

  path = File.join(cache_path,c['identifier'],'variables.json')
  File.open(path,'r'){|f| puts f.read}
end

def list_geography
  c_arg = @cu.required['command']
  c = @cu.commands[c_arg]

  ($stderr.puts "Command not found: #{c_arg}"; exit 1) unless c
  ($stderr.puts "No geography found for command: #{c_arg}"; exit 1) unless c['identifier']

  path = File.join(cache_path,c['identifier'],'geography.json')
  File.open(path,'r'){|f| puts f.read}
end

def update_commands
  #TODO rescue parse errors, old must be array
   old = JSON.parse(File.open(commands_path,'r').read)
   #implicit assumption: datasets will not be removed in the future
   new = (generate_commands + old).uniq{|c| c['long']}.sort_by{|c| c['long']}
   File.open(commands_path,'w+'){|f| f.puts(JSON.pretty_generate(new))}

   refresh_cache
end
#################################################################################

Kernel.exec(generate_command)

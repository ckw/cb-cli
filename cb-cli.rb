#! /usr/bin/env ruby

require 'cli_utils'
require 'json'
require 'yaml'
require 'fileutils'

def generate_command
  @cu = CliUtils.new(commands_path)
  help if (!@cu.command || !(@cu.optional.keys & ['h', 'help']).empty?)

  init_config unless File.exist?(config_path)
  @config = YAML.load(File.open(config_path,'r').read)

  key = (@config['defaults'] || {})['api_key']
  ($stderr.puts "No key specified in #{config_path}"; exit 1) unless key

  (eval @cu.eval; exit) if @cu.eval

  com = @cu.commands[@cu.command]
  query = "curl -s -S '#{com['webService']}#{build_query}&key=#{key}'"
  (puts query; exit) unless (@cu.optional.keys & ['d', 'dry-run']).empty?

  query
end

def build_query
  query = @cu.required.map{|k,v| "#{k}=#{v}"}.join('&')
  query = "?#{query}" if query
  in_param = @cu.optional['in']
  query = "#{query}&in=#{in_param}" if (query && in_param)
  query
end

def commands_path
  return @commands_path if @commands_path
  @commands_path = File.join(cache_path, 'commands.json')

  unless File.exist?(@commands_path)
   from_git = JSON.parse(File.open(commands_path_git,'r').read)
   new = (from_git + generate_commands).uniq{|c| c['long']}.sort_by{|c| c['long']}
   File.open(commands_path,'w+'){|f| f.puts(JSON.pretty_generate(new))}
  end

  @commands_path
end

def commands_path_git
  return @commands_path_git if @commands_path_git
  @commands_path_git = File.join(File.dirname(follow_if_link(__FILE__)), 'src', 'commands.json')
end

def cache_path
  return @cache_path if @cache_path
  @cache_path = File.join(cb_directory, 'cache')
  FileUtils.mkdir_p(@cache_path) unless Dir.exist?(@cache_path)
  @cache_path
end

def generate_commands
  datasets.map{|d|
    vintage = d['c_vintage']
    long = d['c_dataset']
    long = (long << vintage) if vintage
    d['long'] = long.join('-')
    d['required'] = ['get', 'for']
    d['optional'] = ['--in']
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

def fetch_variables(command)
  dir = File.join(cache_path,command['identifier'])
  FileUtils.mkdir_p(dir)

  uri = command['c_variablesLink']
  fp = File.join(dir,'variables.json')
  `curl -o #{fp} -s -S #{uri}`
end

def fetch_geography(command)
  dir = File.join(cache_path,command['identifier'])
  FileUtils.mkdir_p(dir)

  uri = command['c_geographyLink']
  fp = File.join(dir,'geography.json')
  `curl -o #{fp} -s -S #{uri}`
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

def help_string
<<HSTR
cb-cli [options] <command>


OPTIONS:
  -d,-dry-run : print the generated curl command, if one exists;
                inoperative for commands which generate no curl string

  -h,-help    : open help using $PAGER or if $PAGER is not set, less;
                providing no command does the same

COMMANDS: (short alternative names in parentheses)
  #{commands_usage.join("\n  ")}


EXAMPLES:
  Note that command arguments should be wrapped in quotes, as there
  are a number of characters which appear frequently in arguments that
  interact poorly with shells. e.g., *

  list usage for all commands:

    cb-cli lc


  print the description for acs1-2012 (The 2012 version of the one year
  American Community Survey, if I am interpreting the output correctly)

    cb-cli dc acs1-2012


  list all variables for acs1-2012:

    cb-cli lv acs1-2012


  list all geographic regions for acs1-2012:

    cb-cli lg acs1-2012


  list the number of householders age 25-44 with income above $200,000
  in Washington State, by congressional district:

    cb-cli acs1-2012 "NAME,B19037_035E" "congressional+district:*" --in "state:53"

  Note that geographic regions tend to have spaces in them, as in the previous
  command: \"congressional district\". When writing commands using such regions,
  replace spaces with \"+\".


HSTR
end

def commands_usage
  @cu.commands.keys.map{|k| @cu.usage(k)}.sort.uniq
end

### EVAL COMMANDS ###############################################################
def list_datasets
  puts JSON.pretty_generate(datasets)
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

def help
  Kernel.exec("echo '#{help_string}' | #{ENV['PAGER'] || 'less'}")
end

def list_commands
  puts commands_usage
end

def list_geography
  c_arg = @cu.required['command']
  c = @cu.commands[c_arg]

  ($stderr.puts "Command not found: #{c_arg}"; exit 1) unless c
  ($stderr.puts "No geography found for command: #{c_arg}"; exit 1) unless c['identifier']

  path = File.join(cache_path,c['identifier'],'geography.json')
  fetch_geography(c) unless File.exist?(path)
  File.open(path,'r'){|f| puts f.read}
end

def list_variables
  c_arg = @cu.required['command']
  c = @cu.commands[c_arg]

  ($stderr.puts "Command not found: #{c_arg}"; exit 1) unless c
  ($stderr.puts "No variables found for command: #{c_arg}"; exit 1) unless c['identifier']

  path = File.join(cache_path,c['identifier'],'variables.json')
  fetch_variables(c) unless File.exist?(path)

  File.open(path,'r'){|f| puts f.read}
end

# this is expensive
def refresh_all_caches
  update_commands
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

def update_commands
  #TODO rescue parse errors, old must be array
   old = JSON.parse(File.open(commands_path,'r').read)
   from_git = JSON.parse(File.open(commands_path_git,'r').read)
   #implicit assumption: datasets will not be removed in the future
   new = (from_git + generate_commands + old).uniq{|c| c['long']}.sort_by{|c| c['long']}
   File.open(commands_path,'w+'){|f| f.puts(JSON.pretty_generate(new))}
end
#################################################################################

Kernel.exec(generate_command)

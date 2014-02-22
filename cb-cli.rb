#! /usr/bin/env ruby
#
require 'cli_utils'
require 'json'

def generate_command
  @cu = CliUtils.new(commands_path)
  #TODO
  (eval @cu.eval; exit) if @cu.eval
end

def commands_path
  return @commands_path if @commands_path
  @commands_path = File.join(File.dirname(follow_if_link(__FILE__)), 'src', 'commands.json')
end

def update_commands
  #TODO rescue parse errors, old must be array
   old = JSON.parse(File.open(commands_path,'r').read)

   #implicit assumption: datasets will not be removed in the future
   new = (generate_commands + old).uniq{|c| c['long']}.sort_by{|c| c['long']}
   File.open(commands_path,'w+'){|f| f.puts(JSON.pretty_generate(new))}
end

def generate_commands
  datasets.map{|d|
    vintage = d['c_vintage']
    long = d['c_dataset']
    long = (long << vintage) if vintage
    d['long'] = long.join('-')
    d
  }
end

def datasets
  return @datasets if @datasets

  datasets_uri = 'http://api.census.gov/data.json'
  @datasets = JSON.parse(`curl -s -S #{datasets_uri}`)
end

def p(arg)
  puts arg.inspect
end

def list_datasets
  puts JSON.pretty_generate(datasets)
end

def list_commands
  #TODO print usage, so expose in cli_utils
  puts JSON.pretty_generate(@cu.commands.map{|k, v| v['long']}.uniq)
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

Kernel.exec(generate_command)

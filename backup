#!/usr/bin/ruby

#########################################################
##
## Author: Jo Vandeginste
##
#########################################################

MYROOT=File.dirname(__FILE__)
$:.unshift(MYROOT)

require "rubygems"
require "fileutils"
require "net/smtp"
require "yaml"
require "slop"
require 'active_support' # deep_merge

["host" , "cycle" , "fileset" , "float" , "fixnum" , "object" , "daemon" ].each {|my_module|
	require my_module
}

opts = Slop.parse do
	banner "#{__FILE__} [options]\n"
	on :n, :dryrun, 'perform a dryrun'
	on :D, "no-daemonize", "don't daemonize"
	on :h, :help, "show this message"
end

if opts[:help]
	puts opts.help
	exit
end


if opts["no-daemonize"]
	puts "Not daemonizing"
else
	raise 'First fork failed' if (pid = fork) == -1
	exit unless pid.nil?

	Process.setsid
	raise 'Second fork failed' if (pid = fork) == -1
	exit unless pid.nil?
	puts "Daemon pid: #{Process.pid}"

	STDIN.reopen '/dev/null'
	STDOUT.reopen '/dev/null', 'a'
	STDERR.reopen STDOUT
end

def warning(message)
	puts "[WARNING] #{message}"
end
def error(message)
	puts "[ERROR] #{message}"
	exit 1
end

def find_subconfig(name, global_config)
	result = global_config.include?(name) ? global_config.delete(name) : "#{name}.yaml"

	(result.is_a?(String) and result.end_with?(".yaml")) ? read_config_from_file(result) : result 
end

def read_config_from_file(filename)
	file = ["/etc/backup", "#{MYROOT}/config", "#{MYROOT}", ""].map{|path| "#{path}/#{filename}"}.select{|file| File.exist?(file)}.first
	if file
		expand_config(YAML.load(File.read(file)))
	else
		warning "No file found for '#{filename}'."
	end
end
def expand_config(config)
	new_config = {}
	config.each{|k, v|
		new_config[k] = find_subconfig(k, config)
	}
	new_config
end

@@system = YAML.load <<EOF
--- 
log_file: /usr/local/backups/meta/daemon.log
mail_from: Your backup service <backups@localhost>
time_between_cycles: 900
meta_directory: /usr/local/backups/meta
max_backup_threads: 2
host_defaults: 
  base_directory: /usr/local/backups
  rsync_path: /usr/bin/rsync
  cycle: Daily
  current_subdir: current
  staging_subdir: .staging
  prune_after: 1296000
  mode: ssh
  contact:
  - root@localhost
  connect:
  - localhost
cycles: cycles.yaml
filesets: filesets.yaml
hosts: hosts.yaml
EOF
@@system.deep_merge!(read_config_from_file("global.yaml"))
@@filesets = @@system["filesets"] || read_config_from_file("filesets.yaml") || {}
@@cycles = @@system["cycles"] || read_config_from_file("cycles.yaml") || {}
@@hosts = @@system["hosts"] || read_config_from_file("hosts.yaml") || {}

def parse_config
	@@daemon = Daemon.new("daemon", @@system)

	@@filesets.each{|k, v|
		Fileset.new(k, v)
	}
	@@cycles.each{|k, v|
		Cycle.new(k, v)
	}
	@@hosts.each{|k, v|
		Host.new(k, @@daemon.host_defaults.merge(v))
	}
end


def reload
	Host.all.each {|o|
		Host.destroy(o)
	}
	Cycle.all.each {|o|
		Cycle.destroy(o)
	}
	Fileset.all.each {|o|
		Fileset.destroy(o)
	}
	Daemon.all.each {|o|
		Daemon.destroy(o)
	}
	parse_config
	nil
end

reload

Host.all.each{|host|
	@@daemon.log host.show_config
}

if opts[:dryrun]
	puts "Dryrun, quitng here"
else
	@@cycle_thread ||= Thread.new {
		while true
			@@daemon.cycle
		end
	}

	@@cycle_thread.join
end

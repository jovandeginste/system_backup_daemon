require "rubygems"
require "popen4"

class Machine
	@@pool ||= {}

	attr_accessor :name, :contact, :connect, :mode, :fileset, :cycle, :base_directory, :current_subdir, :staging_subdir, :prune_after, :meta_directory, :log_file

	def self.new(name, params = {})
		f = self.find(name.to_sym)
		if f.nil?
			super(name, params)
		else
			f
		end
	end

	def self.destroy(name)
		@@pool.delete name.to_sym
	end

	def self.find(name)
		@@pool[name.to_sym]
	end

	def self.all
		@@pool.values
	end

	def initialize(name, params = {})
		@@pool[name.to_sym] = self
		self.name = name
		self.parse_params(params)

		self.mode ||= "ssh"
		self.contact ||= "root@localhost".arrayfy
		self.connect ||= "localhost".arrayfy
		self.meta_directory ||= @@daemon.meta_directory
		self.log_file ||= File.join(self.meta_directory, "#{self}.log")
	end

	def parse_params(params)
		[:mode, :cycle, :base_directory, :current_subdir, :staging_subdir, :prune_after, :meta_directory, :log_file].each{|key|
			self.send "#{key}=", params[key]
		}
		[:contact, :fileset].each{|key|
			self.send "#{key}=", params[key].arrayfy
		}
		connect = params[:connect]
		self.connect ||= {}
		case connect.class.to_s
		when "String"
			self.connect[connect] = {}
		when "Array"
			connect.each{|c|
				self.connect[c] = {}
			}
		when "Hash"
			connect.each{|key, value|
				self.connect[key] = value
			}
		end
	end

	def includes
		self.fileset.collect{|f| f.includes}.flatten.uniq.compact
	end

	def excludes
		self.fileset.collect{|f| f.excludes}.flatten.uniq.compact
	end

	def to_s
		"#{self.name}"
	end
	def to_sym
		self.name.to_sym
	end
	def fileset
		@fileset.collect{|f| Fileset.find(f)}
	end
	def filesets
		self.fileset
	end
	def fileset_name
		@fileset
	end
	def fileset_names
		self.fileset_name
	end
	def contacts
		contact
	end
	def cycle
		Cycle.find(@cycle)
	end
	def cycle_name
		@cycle
	end
	def find_cycle(connect_host)
		c = self.connect[connect_host][:cycle]
		c.nil? ? self.cycle : Cycle.find(c)
	end

	def backup_root_directory
		File.join(self.base_directory, self.name.to_s)
	end
	def backup_staging_directory
		File.join(self.backup_root_directory, self.staging_subdir)
	end
	def backup_current_directory
		File.join(self.backup_root_directory, self.current_subdir)
	end
	def lock_file
		File.join(self.meta_directory, "#{self.name.to_s}.lock")
	end
	def meta_file
		File.join(self.meta_directory, "#{self.name.to_s}.last")
	end

	def mail_file
		File.join(self.meta_directory, "#{self.name.to_s}.mail")
	end

	def backup_due?(connect_host)
		File.exist?(self.meta_file) && ! File.exist?(self.lock_file) && self.find_cycle(connect_host).expired(self.meta_file)
	end

	def connect_host
		self.connect.keys.first
	end
	def connect_hosts
		self.connect.keys
	end
	def last_backup
		File.exist?(self.meta_file) ? File.mtime(self.meta_file) : nil
	end
	def last_mail
		File.exist?(self.mail_file) ? File.mtime(self.mail_file) : nil
	end

	def show_config
		result = "================================================================================
Config for #{self}:
	* Mode: #{self.mode}
	* Connect: #{self.connect_hosts.join(", ")}"
	self.connect_hosts.each {|host|
		result += "
		* Cycle for #{host}: #{self.find_cycle(host).name}
			* Min age: #{self.find_cycle(host).min_age} days
			* Max age: #{self.find_cycle(host).max_age} days
			* Check every: #{self.find_cycle(host).check} minutes"
	}
	result += "
	* Contact: #{self.contact.join(", ")}
	* Fileset(s): #{self.fileset_names.join(", ")}
		* Including: #{self.includes.join(", ")}
		* Excluding: #{self.excludes.join(", ")}
	* Backing up to: #{self.backup_root_directory}
		* current: #{self.backup_current_directory}
		* staging: #{self.backup_staging_directory}
	* Files:
		* logfile: #{self.log_file}
		* metafile: #{self.meta_file}
		* lockfile: #{self.lock_file}
	* Last backup: #{self.last_backup}
	* Locked: #{self.locked? ? "yes" : "no"}
================================================================================"

result
	end

	def expired_hosts
		if  File.exist?(self.meta_file)
			last_backup = File.mtime(self.meta_file)
			self.connect_hosts.select{|ch| Time.now > last_backup + self.find_cycle(ch).max_age.days}
		else
			self.connect_hosts
		end
	end

	def due_hosts
		if  File.exist?(self.meta_file)
			last_backup = File.mtime(self.meta_file)
			self.connect_hosts.select{|ch| Time.now > last_backup + self.find_cycle(ch).min_age.days}
		else
			self.connect_hosts
		end
	end

	def live_hosts
		hosts = self.connect_hosts.select{|host| self.ping(host)}
	end

	def live_due_hosts
		hosts = self.due_hosts.select{|host| self.ping(host)}
	end

	def ping(host)
		`ping -c 1 -W 1 #{host}`
		$?.exitstatus == 0
	end

	def backup_expired?
		self.expired_hosts == self.connect_hosts
	end

	def sane?
		unless File.directory?(self.backup_root_directory)
			self.log "Machine directory #{self.backup_root_directory} does not exist; please correct!"
			return false
		end
		unless File.writable?(self.backup_root_directory)
			self.log "Machine directory #{self.backup_root_directory} not writable; please correct!"
			return false
		end
		return true
	end

	def locked?
		File.exists?(self.lock_file) and File.mtime(self.lock_file) > Time.now - 6.hours
	end

	def unlock
		FileUtils.rm_rf self.lock_file
	end

	def lock
		FileUtils.touch self.lock_file
	end

	def perform_backup(connect_host)
		return false unless self.connect_hosts.include? connect_host
		return false unless self.sane?
		return false if self.locked?
		self.lock
		t1 = Time.now

		FileUtils.rmtree self.backup_staging_directory if File.directory? self.backup_staging_directory 

		date_subdir = Time.now.localtime.strftime("%Y-%m-%d_%H-%M-%S")
		date_dir = File.join(self.backup_root_directory, date_subdir)

		unless File.directory?(self.backup_current_directory)
			FileUtils.mkdir self.backup_current_directory
		end

		fromdir = case self.mode.to_sym
			  when :local
				  "\"#{self.includes.join('" "')}\""
			  when :linux
				  "\"#{self.includes.collect{|inc| "#{connect_host}:#{inc}"}.join('" "')}\""
			  when :windows
				  "\"#{self.includes.collect{|inc| "#{connect_host}::#{inc}"}.join('" "')}\""
			  end

		rsync_command = "echo '#{self.excludes.join("\n")}' | /usr/bin/rsync -zt --delete --delete-excluded -RHhax #{fromdir} #{self.backup_current_directory} --itemize-changes --exclude-from=- 2>&1"
		self.log ">> #{rsync_command}"

		status = POpen4::popen4( rsync_command ) do |stdout, stderr, stdin|
			stdout.each do |line|
				self.lock
				self.log line
			end
		end
		exit_code = status.exitstatus
		self.lock

		t2 = Time.now
		self.log "Rsync exit code: #{exit_code}; this took: #{(t2 - t1).to_i.seconds} seconds"

		case exit_code
			#   0      Success
			#   1      Syntax or usage error
			#   2      Protocol incompatibility
			#   3      Errors selecting input/output files, dirs
			#   4      Requested  action not supported: an attempt was made to manipulate 64-bit files on a platform 
			#          that cannot support them; or an option was specified that is supported by the client and not by the server.
			#   5      Error starting client-server protocol
			#   6      Daemon unable to append to log-file
			#   10     Error in socket I/O
			#   11     Error in file I/O
			#   12     Error in rsync protocol data stream
			#   13     Errors with program diagnostics
			#   14     Error in IPC code
			#   20     Received SIGUSR1 or SIGINT
			#   21     Some error returned by waitpid()
			#   22     Error allocating core memory buffers
			#   23     Partial transfer due to error
			#   24     Partial transfer due to vanished source files
			#   25     The --max-delete limit stopped deletions
			#   30     Timeout in data send/receive
			#   35     Timeout waiting for daemon connection

		when 0, 23, 24
			snapshot_command = "find #{self.backup_current_directory} -depth -print0 | cpio -pdm0 --link #{self.backup_staging_directory}"

			self.log ">> #{snapshot_command}"
			status = POpen4::popen4( snapshot_command ) do |stdout, stderr, stdin|
				stdout.each do |line|
					self.lock
					self.log line
				end
			end
			snapshot_exit_code = status.exitstatus
			t3 = Time.now
			self.log "Snapshot exit code: #{snapshot_exit_code}; this took: #{(t3 - t2).to_i.seconds} seconds"

			if snapshot_exit_code == 0 and
				rsync_command = "/usr/bin/rsync -vHhax #{self.backup_current_directory}/ #{File.join(self.backup_staging_directory, self.backup_current_directory)} 2>&1"
				self.log ">> #{rsync_command}"

				status = POpen4::popen4( rsync_command ) do |stdout, stderr, stdin|
					stdout.each do |line|
						self.lock
						self.log line
					end
				end
				exit_code = status.exitstatus
				self.lock

				t4 = Time.now
				self.log "Resync exit code: #{exit_code}; this took: #{(t4 - t3).to_i.seconds} seconds"

				FileUtils.move File.join(self.backup_staging_directory, self.backup_current_directory), date_dir and
				FileUtils.rmtree self.backup_staging_directory
				t5 = Time.now
				self.log "Total backup took: #{(t5 - t1).to_i.seconds} seconds"
				self.touch_meta_file
			else
				self.unlock
				return false
			end
		else
			self.log "Rsync failed..."
			self.unlock
			return false
		end

		self.unlock
		return true
	end

	def check_snapshots
		return false unless self.sane?
		snapshots = Dir.new(self.backup_root_directory).entries.select{|e| e.match('^\d{4}(-\d{2}){2}_\d{2}(-\d{2}){2}$')}
		pruned = 0
		snapshots.each{|s|
			time = File.mtime(File.join(self.backup_root_directory, s))
			if time < Time.now - self.prune_after
				self.log "Snapshot #{s} is too old - removing.."
				self.log FileUtils.rmtree File.join(self.backup_root_directory, s)
				pruned += 1
			end
		}
		self.log "Found #{snapshots.size} snapshots, pruned #{pruned}."
		nil
	end

	def touch_meta_file
		FileUtils.touch(self.meta_file)
	end

	def touch_mail_file
		FileUtils.touch(self.mail_file)
	end

	def log(line)
		if line.class == Array
			line = line.join("\n")
		end
		date = Time.now.localtime.strftime("%Y/%m/%d %H:%M:%S")
		log_line = ""
		line.split("\n").each{|l|
			log_line += "[#{date}] [#{self}] #{l}\n"
		}
		puts log_line
		if self.log_file.not_blank?
			if (File.file?(self.log_file) and File.writable?(self.log_file)) or
				(! File.exists?(self.log_file) and File.writable?(File.dirname self.log_file))
				File.open(self.log_file, 'a') {|f| f.write log_line }
			end
		else
			line.split("\n").each{|l|
				Daemon.all.first.log "[#{self.to_s}] #{l}"
			}
		end
	end

	def force_perform_backup
		live = self.live_hosts
		self.log "Live hosts: #{live.join(", ")}"
		if live.empty?
			self.log "No live hosts - skipping till next cycle"
			return false
		else
			host = live.first
			self.log "Picking the first: #{host}"
			r = self.perform_backup(host)

			self.log r ? "Backup succeeded." : "Backup failed."
			return r
		end
	end

	def check_to_backup
		due = self.due_hosts
		if due.empty?
			self.log "Nothing to see here, carry on..."
			return true
		else
			self.log "Due hosts for me: #{due.join(", ")}"
			live = self.live_due_hosts
			self.log "Live hosts: #{live.join(", ")}"
			if live.empty?
				self.log "No live hosts - skipping till next cycle"
				return false
			else
				host = live.first
				self.log "Picking the first: #{host}"
				r = self.perform_backup(host)

				self.log r ? "Backup succeeded." : "Backup failed."
				return r
			end
		end
	end

	def send_mail
		return false if self.last_mail.nil? or self.last_mail < Time.now + 1.day
		@@daemon.log "Backup for #{self} expired."
		self.contacts.each{|contact|
			msg = <<EOF_MESSAGE
Dear #{contact},

This mail is to inform you that #{self} is in desperate need for a fresh backup!
Its last successful backup finished around: #{self.last_backup}

The configuration for this machine:

#{self.show_config}

Sincerely,

#{@@daemon.mail_from}
EOF_MESSAGE
begin
	send_email @@daemon.mail_from, contact, "Backup overdue for: #{self}", msg
end
		}
		self.touch_mail_file
		return true
	end
end

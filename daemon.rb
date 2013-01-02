
class Daemon
	@@pool ||= {}
	@@backup_threads ||= []

	attr_accessor :name, :meta_directory, :time_between_cycles, :host_defaults, :mail_from, :log_file, :max_backup_threads

	def self.new(name, params = {})
		f = self.find(name)
		if f.nil?
			super(name, params)
		else
			f
		end
	end

	def self.find(name)
		@@pool[name.to_sym]
	end

	def self.destroy(name)
		@@pool.delete name.to_sym
	end

	def self.all
		@@pool.values
	end

	def initialize(name, params = {})
		@@pool[name.to_sym] = self
		self.name = name
		self.parse_params(params)
	end

	def parse_params(params)
		[:meta_directory, :time_between_cycles, :host_defaults, :mail_from, :log_file, :max_backup_threads].each{|key|
			self.send "#{key}=", (params[key] || params[key.to_s])
		}
	end

	def to_s
		"#{self.name}"
	end
	def to_sym
		self.name.to_sym
	end

	def log(line)
		if line.class == Array
			line = line.join("\n")
		end
		date = Time.now.localtime.strftime("%Y/%m/%d %H:%M:%S")
		log_line = ""
		line.split("\n").each{|l|
			log_line += "[#{date}] #{l}\n"
		}
		puts log_line
		if self.log_file.not_blank?
			if (File.file?(self.log_file) and File.writable?(self.log_file)) or
				(! File.exists?(self.log_file) and File.writable?(File.dirname self.log_file))
				File.open(self.log_file, 'a') {|f| f.write log_line }
			end
		end
	end

	def backup_cycle
		Host.all.each{|host|
			self.log "Checking: #{host}"
			@@backup_threads.delete_if {|t| t.status.nil? or ! t.status}
			while @@backup_threads.size >= self.max_backup_threads
				sleep 1
				@@backup_threads.delete_if {|t| t.status.nil? or ! t.status}
			end
			@@backup_threads << Thread.new {
				host.check_snapshots
				host.check_to_backup
			}
			sleep 1
			self.log "Done."
		}
		while @@backup_threads.size > 0
			sleep 1
			@@backup_threads.delete_if {|t| t.status.nil? or ! t.status}
		end
		self.log "All done."
	end

	def check_timeout
		expired = []
		Host.all.each{|host|
			if host.backup_expired?
				host.send_mail
			end
		}
		expired
	end

	def cycle
		self.log "Start of cycle";
		self.backup_cycle
		self.check_timeout
		self.log "End of cycle; sleeping for: #{self.time_between_cycles} seconds";
		sleep self.time_between_cycles.seconds
	end

	def status
		"Running ..."
	end
end

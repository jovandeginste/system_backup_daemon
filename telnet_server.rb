require 'gserver'
class TelnetServer < GServer
	def serve(io)
		while true
			break unless main_menu(io)
		end
	end
	def main_menu(io)
		io.puts "=====================================
==                                 ==
==         Backup service          ==
==                                 ==
=====================================

1) status
2) show config
3) perform backup
x) exit

Your choice:"
		case io.readline.chomp
		when "x"
			return false
		when "1"
			io.puts @@daemon.status
		when "2"
			show_config_menu(io)
		when "3"
			perform_backup_menu(io)
		else
			io.puts "Unknown option."
		end
		return true
	end

	def perform_backup_menu(io)
		io.puts "Perform backup for:"
		io.puts self.list_servers

		n = io.readline.chomp.to_i
		if n > Machine.all.size or n < 1
			io.puts "Not a valid option: #{n}"
		else
			io.puts "Performing backup for: #{n}"
			Machine.all[n - 1].force_perform_backup
		end
	end

	def show_config_menu(io)
		io.puts "Show config for:"
		io.puts self.list_servers

		n = io.readline.chomp.to_i
		if n > Machine.all.size or n < 1
			io.puts "Not a valid option: #{n}"
		else
			io.puts Machine.all[n - 1].show_config
		end
	end

	def list_servers
		x = ""
		Machine.all.each_index {|i|
			x += " #{i + 1}) #{Machine.all[i]}\n"
		}
		x
	end
end


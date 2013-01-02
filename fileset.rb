
class Fileset
	@@pool ||= {}

	attr_accessor :name, :includes, :excludes

	def self.new(name, params = {})
		f = self.find(name.to_sym)
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
		[:includes, :excludes].each{|key|
			self.send "#{key}=", (params[key] || params[key.to_s]).arrayfy
		}
	end

	def to_s
		"#{self.name}"
	end
	def to_sym
		self.name.to_sym
	end
end

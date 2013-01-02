
class Cycle
	@@pool ||= {}

	attr_accessor :name, :min_age, :max_age, :check

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
		[:max_age, :min_age, :check].each{|key|
			self.send "#{key}=", (params[key] || params[key.to_s])
		}
	end

	def to_s
		"#{self.name}"
	end
	def to_sym
		self.name.to_sym
	end
end

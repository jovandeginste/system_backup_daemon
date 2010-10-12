class Fixnum
	def second
		self.seconds
	end
	def seconds
		self
	end
	def minute
		self.minutes
	end
	def minutes
		self.seconds * 60
	end
	def hour
		self.hours
	end
	def hours
		self.minutes * 60
	end
	def day
		self.days
	end
	def days
		self.hours * 24
	end
	def week
		self.weeks
	end
	def weeks
		self.days * 7
	end
	def month
		self.months
	end
	def months
		self.years / 12
	end
	def year
		self.years
	end
	def years
		self.days * 365
	end
end

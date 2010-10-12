class Object
	def arrayfy
		[self].flatten.compact
	end

	def not_blank?
		! self.blank?
	end

	def not_nil?
		! self.nil?
	end

	def blank?
		self.nil?
	end
end

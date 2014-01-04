LISTENERS = []

class Analysist

	def Analysist.create(compilers)
		compilers = [compilers] unless compilers.is_a? Array

		anal = Analysist.new
		anal.add_listener(compilers)

		anal
	end

	def Analysist.register_listener(listener)
		puts "Registering listener #{listener.inspect}" if VERBOSE
		LISTENERS << listener
	end

	def <<(line)
		@listener.each do |l| l.analyse_line(line) end
	end

	def finish!
		@listener.each do |l| l.finalise if l.respond_to? :finalise end
	end

	def data
		ret = {}
		@listener.each do |l| ret.merge!(l.projects) end
		ret
	end

	def add_listener(compilers)
		LISTENERS.each do |listener|
			puts "Adding listener #{listener.inspect}, responds to #{compilers.inspect}" if listener.does? compilers and VERBOSE
			@listener << listener.new if listener.does?(compilers)
		end
	end

	private

	def initialize
		@listener = []
	end

end

Dir.glob(File.expand_path(File.dirname(__FILE__)) + "/listeners/*.rb").each { |listener|
	require listener
}

exit if LISTENERS.empty?
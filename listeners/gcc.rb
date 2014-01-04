class GCCCMakeListener

	attr_reader :projects

	def initialize
		@projects = {}
		@names = []
		@id = 1

		# CMake is nice with providing project names in this case
		open("CMakeFiles/Makefile2").each_line do |line|
			if line =~ /Built target/ then
				@names << line[21..-3]
			end
		end
	end

	def analyse_line(line)
		data = REGEX.match(line)

		if data then
			@projects[@id] = { :ID => @id, :Name => @names[@id-1], :Messages => [], :Start => Time.now } unless @projects.has_key? @id
			@projects[@id][:Messages] << { :File => data["file"], :Line => data["line"].to_i, :Column => data["col"].to_i, :Type => data["type"], :Message => data["message"] } if data["file"]
			
			 # TODO: Figure out a better way to find when projects are finished
			if data["name"] or data["error"] then
				@projects[@id][:Success] = (data["error"] ? false : true)
				@projects[@id][:End] = Time.now
				@id = @id + 1
			end
		end
	end

	def finalise
		temp = @projects

		totaltime = 0
		success = true

		temp = temp.map do |id, project|
			success = false unless project[:Success]
			project[:Time] = project[:End] - project[:Start]
			project.delete :End
			project.delete :Start

			totaltime = totaltime + project[:Time]

			[project[:Name], project]
		end

		@projects = { :Projects => Hash[*temp.flatten], :TotalTime => totaltime, :Success => success }
	end

	def GCCCMakeListener.does?(compilers)
		cmake = false
		gcc = false

		compilers.each do |comp|
			cmake = true if comp =~ /cmake/i
			gcc = true if comp =~ /gcc/i
		end

		cmake and gcc
	end

	private

	REGEX = /(^(?<file>.+):(?<line>\d+):(?<col>\d+): (?<type>warning|error):\s+(?<message>.*)|(Built target (?<name>.*))|(make\[.*\].*(?<error>Error 1)))/

end

Analysist.register_listener(GCCCMakeListener)

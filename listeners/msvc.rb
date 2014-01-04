class MSVCAnalysist

	attr_reader :projects

	def initialize
		@projects = {}
	end

	def analyse_line(line)
		data = REGEX.match(line)

		if data and data["id"] then
			@projects[data["id"]] = { :ID => data["id"].to_i, :Messages => [] } unless @projects.has_key? data["id"]
			@projects[data["id"]][:Name] = data["name"] if data["name"]
			@projects[data["id"]][:Messages] << { :File => data["file"], :Line => (data["line"] ? data["line"].to_i : nil), :Type => (data["type"] ? (data["type"]["fatal"] ? "error" : data["type"]) : "info"), :Code => data["code"], :Message => data["message"] } if data["file"]
			@projects[data["id"]][:Success] = data["success"] == "succeeded" if data["success"]
			if data["time"] then
				parts = data["time"].split(/:|\./)

				hours = parts[0].to_f
				minutes = parts[1].to_f
				seconds = parts[2].to_f
				hundreds = parts[3].to_f
				length = ((hundreds/100) + seconds + (minutes * 60) + (hours * 60 * 60))
				
				@projects[data["id"]][:Time] = length
			end
		end
	end

	def finalise
		temp = @projects

		totaltime = 0

		temp.each do |id, project|
			totaltime = totaltime + project[:Time] if project[:Time]
			project[:MessageCount] = {}
			project[:Messages].each do |message|
				code = message[:Code]
				project[:MessageCount][code] = 0 unless project[:MessageCount][code]
				project[:MessageCount][code] = project[:MessageCount][code] + 1
			end
		end

		success = true
		temp = temp.map do |id, project|
			success = false unless project[:Success]
			[project[:Name], project]
		end

		@projects = { :Projects => Hash[*temp.flatten], :TotalTime => totaltime, :Success => success }
	end

	def MSVCAnalysist.does?(compilers)
		compilers.each do |comp|
			return true if comp =~ /(msvc|visual studio)/i
		end

		false
	end

	private

	REGEX = /^((?<id>\d+)>\s*((-+ .*Project: (?<name>\w*).*)|((?<file>.*)(\((?<line>\d+)\)|\s):(\s(?<type>warning|error|info|fatal( error)?) (?<code>\w+):) (?<message>.*))|(Build (?<success>succeeded|FAILED).)|(Time Elapsed (?<time>(\d{2}(:|.)?)+))))$/

end

Analysist.register_listener(MSVCAnalysist)

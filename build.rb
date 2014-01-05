require_relative 'globals.rb'
require_relative 'analytics.rb'
require 'json'

class Build

	attr_accessor :name, :buildpath, :sourcepath, :last_succeeded, :last_analytics, :last_revision
	attr_reader :revision, :succeeded, :analytics

	def initialize(data, path)
		@env = {}
		if CONFIG["path"] then
			path_source = CONFIG["path"][OS.name?] or nil

			if path_source then
				@env["PATH"] = []
				path_source.each { |p|
					@env["PATH"] << p
				}
				@env["PATH"] = @env["PATH"].join(OS.windows? ? ";" : ":")
			end
		end

		@name = data["name"]
		@buildpath = File.expand_path(path)
		@sourcepath = File.expand_path(data["source"])
		@analyser = Analysist.create data[OS.name?]["compiler"]
		
		storedata = { :Succeeded => true, :Revision => nil }
		storedata = Psych.load(open("#{@buildpath}/.lastbuild").read) if File.exists? "#{@buildpath}/.lastbuild"

		@last_succeeded = storedata[:Succeeded]
		@last_revision = storedata[:Revision]
		@last_analytics = JSON.load(open("#{@buildpath}/.analytics.json")) if File.exists? "#{@buildpath}/.analytics.json"
	end

	def update(branch)
		puts "Changing directory to #{@sourcepath}" if VERBOSE
		Dir.chdir(@sourcepath)
		puts "Getting latest version of #{branch}"
		branch = branch.split('/')
		
		return false unless run_actions(["git remote update #{branch[0]}", "git checkout #{branch[1]}", "git pull #{branch.join(' ')}"])

		IO.popen([@env, "git", "log", "-1", "--pretty=format:%h"]) do |fd|
			@revision = fd.read
		end
	end

	def prepare_build(actions)
		puts "Changing directory to #{@buildpath}" if VERBOSE
		Dir.chdir(@buildpath)
		puts "Preparing build"
		
		run_actions(actions)
	end

	def build(actions)
		puts "Changing directory to #{@buildpath}" if VERBOSE
		Dir.chdir(@buildpath)
		puts "Running build"
		buildlog = File.open("build.log", "wt")
		
		run_actions(actions) do |fd|
			fd.each_line do |line|
				buildlog << line
				@analyser << line
				$stdout << line if VERBOSE
			end
		end
		@analyser.finish!

		@analytics = @analyser.data
		@succeeded = @analytics[:Success]
		buildlog.close
	end

	def store
		File.open("#{@buildpath}/.lastbuild", "wt") do |file|
			file << Psych.dump({
				:Succeeded => @succeeded,
				:Revision => @revision
				})
		end

		File.open("#{@buildpath}/.analytics.json", "wt") do |file|
			file << @analytics.to_json
		end
	end

	private

	def run_actions(actions)
		actions.each do |cmd|
			optional = cmd[0] == '?'
			cmd = cmd[1..-1] if optional
			args = cmd.scan(/(?:["'](?:\\.|[^"'])*["']|[^"' ])+/).map { |v| v.chomp('"').chomp("'").reverse.chomp('"').chomp("'").reverse }

			print "-  #{cmd} "
			print "(optional) " if optional
			
			if block_given? then
				IO.popen([@env, *args, :err => [:child, :out]], &Proc.new)
			else
				IO.popen([@env, *args, :err => [:child, :out]]) do |fd| fd.each_line do |_| end end unless VERBOSE
				IO.popen([@env, *args]) do |fd| fd.each_line do |line| $stdout << line end end if VERBOSE
			end

			puts_right(cmd.length+(optional ? 15 : 4), "[#{"OK".green}]") if $?.exitstatus == 0
			puts_right(cmd.length+(optional ? 15 : 4), "[#{"!!".colorize(optional ? 33 : 31)}]") if $?.exitstatus != 0

			return false if $?.exitstatus != 0 and not optional
		end

		true
	end

end
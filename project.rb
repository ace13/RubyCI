#!/bin/env ruby

require_relative 'build.rb'
require_relative 'globals.rb'
require_relative 'actions.rb'

class Project

	attr_accessor :name, :force, :skip

	def initialize(file)
		return unless file
		@data = Psych.load(open(file).read)
		raise ArgumentError, "Could not load build information from #{file}!" unless @data

		@buildinfo = @data[OS.name?] or nil
		raise "Could not find build information for your current OS in the build file!" unless @buildinfo

		@build = Build.new @data, File.expand_path(File.dirname(file))
	end

	def build!
		return unless @data

		puts "Skipping build of project #{@data["name"]}!", "" if @skip
		unless @skip then
			puts "Starting build of project #{@data["name"]}!", ""

			@build.update(@data["git"])
			puts

			puts "Skipping build, last build on this revision succeeded. Use -f to force the issue" if @build.revision == @build.last_revision and @build.last_succeeded and not @force
			return true if @build.revision == @build.last_revision and @build.last_succeeded and not @force

			prepared = @build.prepare_build @buildinfo["before_build"] unless @buildinfo["before_build"].is_a? NilClass or @buildinfo["before_build"].empty?
			puts "Prebuild failed, aborting build." if not prepared
			return false unless prepared
			puts

			@build.build(@buildinfo["build"])
			puts
		end

		puts "Running post-build!"
		if @buildinfo["after_build"] then
			after_build = @buildinfo["after_build"]

			if @build.succeeded then
				run_actions(after_build["onsuccess"]) unless after_build["onsuccess"] == nil
			else
				run_actions(after_build["onfailure"]) unless after_build["onfailure"] == nil
			end

			run_actions(after_build["onchange"]) unless after_build["onchange"] == nil or @build.succeeded == @build.last_succeeded
			run_actions(after_build["regardless"]) unless after_build["regardless"] == nil
		end
		puts

		@build.store
	end

	private

	def run_actions(from)
		if from.is_a? Array then
			from.each do |arr| run_actions arr end
		else
			from.each do |action, data|
				print "-  #{action}"
				begin
					ACTIONS[action.to_sym].call(@build, data) if ACTIONS.member? action.to_sym
					puts_right action.length+3, " [#{"OK".green}]" if ACTIONS.member? action.to_sym
				rescue Exception => e
					puts_right action.length+3, " [#{"!!".red}]" unless VERBOSE
					puts e.message, e.backtrace, "" if VERBOSE
				end
				puts_right action.length+3, " [#{"??".yellow}]" unless ACTIONS.member? action.to_sym
			end
		end
	end

end

if __FILE__ == $0 then
	if ARGV.length > 0 then
		begin
			a = Project.new ARGV[0]
		rescue Exception => e
			puts e.message
			puts e.backtrace
			exit false
		end

		if (ARGV[1] or '')[0] == '-' then
			VERBOSE = true if ARGV[1]['v']
			a.skip = true  if ARGV[1]['s']
			a.force = true if ARGV[1]['f']
		end

		a.build!
	else
		info = <<INFO
Usage:
	$0 path/to/buildfile.yml [-fsv]
INFO

		puts info
	end
end
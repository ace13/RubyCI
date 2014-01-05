require 'net/ftp'
require 'fileutils.rb'

PROTOCOLS = {
	:ftp => Proc.new do |file, host, destination|
		raise "No login details for ftp://#{host}" unless CONFIG.has_key? "publish" and CONFIG["publish"]["ftp"].has_key? host

		login = CONFIG["publish"]["ftp"][host]

		ftp = Net::FTP.new(host)
		ftp.login(login["user"], login["password"])
		ftp.chdir(File.dirname destination)

		ftp.putbinaryfile(file, File.basename(destination))

		ftp.close
	end,

	:file => Proc.new do |file, destination|
		FileUtils.copy(file, destination)
	end
}

add_action("publish") do |build, action|
	source = action["source"]
	protocol = action["destination"].partition("://")[0].to_sym
	raise "No idea how to use protocol #{protocol}" unless PROTOCOLS.has_key? protocol

	source = Dir.glob(source)
	unless source.is_a? NilClass or source.empty? then
		source.sort! { |b,a| File.mtime(a) <=> File.mtime(b) }

		destination = parse_string(action["destination"].partition("://")[2], build)

		PROTOCOLS[protocol].call(source[0], *destination.split(":"))
	end
end
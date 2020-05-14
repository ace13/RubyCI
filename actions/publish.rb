require 'fileutils.rb'

require 'uri'
require 'uri/scp'

PROTOCOLS = {
	:ftp => Proc.new do |file, uri|
		require 'net/ftp'
		username = uri.user if uri.user
		password = uri.password if uri.password

		unless username and password then
			login = CONFIG["publish"]["ftp"][uri.host] or { }

			username = login["user"] or nil unless username
			password = login["password"] or nil unless password
		end

		raise "No login details for #{uri.host}" unless username and password

		puts "Logging into #{host} as #{username}." if VERBOSE

		Net::FTP.open(host) do |ftp|
			ftp.login(username, password)

			puts "Publishing #{file} to #{uri.path}." if VERBOSE

			ftp.chdir(File.dirname uri.path)
			ftp.putbinaryfile(file, File.basename(uri.path))
		end
	end,

	:scp => Proc.new do |file, uri|
		require 'net/scp'
		username = uri.user if uri.user
		password = uri.password if uri.password

		unless username and password then
			login = { }
			login = CONFIG["publish"]["scp"][uri.host] if CONFIG["publish"].has_key? "scp" and CONFIG["publish"]["scp"].has_key? uri.host

			username = login["user"] or nil unless username
			password = login["password"] or nil unless password
		end

		raise "No login details for #{uri.host}" unless username and password

		puts "Logging into #{uri.host} as #{username}." if VERBOSE
		puts "Publishing #{file} to #{uri.path}." if VERBOSE

		Net::SCP.upload!(uri.host, username, file, uri.path, ssh: { password: password })
	end,

	:s3 => Proc.new do |file, uri|
		require 'aws-sdk-s3'
		username = uri.user if uri.user
		password = uri.password if uri.password

		unless username and password then
			login = { }
			login = CONFIG["publish"]["s3"][uri.host] if CONFIG["publish"].has_key? "s3" and CONFIG["publish"]["s3"].has_key? uri.host

			username = login["user"] or nil unless username
			password = login["password"] or nil unless password
		end

		raise "No login details for #{uri.host}" unless username and password

		components = uri.path.split('/').reject(&:empty?)
		bucket = components.shift
		path = components.join('/')

		cred = Aws::Credentials.new username, password
		client = Aws::S3::Resource.new region: 'eu-west', endpoint: "#{uri.dup.tap { |u| u.scheme = 'https'; u.path = '' }}",
			credentials: cred, force_path_style: true

		client.bucket(bucket).object(path).upload_file(file)
	end,

	:file => Proc.new do |file, uri|
		FileUtils.copy(file, uri.path)
	end
}

add_action("publish") do |build, action|
	source = action["source"]
	uri = URI.parse(parse_string(action["destination"], build))
	raise "No idea how to use protocol #{uri.scheme}" unless PROTOCOLS.has_key? uri.scheme.to_sym

	source = Dir.glob(source)
	unless source.is_a? NilClass or source.empty? then
		source.sort! { |b,a| File.mtime(a) <=> File.mtime(b) }

		PROTOCOLS[uri.scheme.to_sym].call(source[0], uri)
	end
end

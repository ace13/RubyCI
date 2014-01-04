ACTIONS = { }

def add_action(name, &block)
	return false unless block_given? and block.arity == 2

	ACTIONS[name.to_sym] = Proc.new
end

def parse_string(string, build)
	split = string.split(/(\{\{|\}\})/)
	
	in_part = false
	new_string = ""
	split.each do |part|
		if part == '{{' then
			in_part = true
		elsif part == '}}' then
			in_part = false
		else
			part = instance_eval(part) if in_part
			new_string << part
		end
	end

	new_string
end

Dir.glob(File.expand_path(File.dirname(__FILE__)) + "/actions/*.rb").each { |action|
	require action
}

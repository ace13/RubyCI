require 'net/smtp'

BASE_MAIL = {
	:message => <<-eos,
From: Ruby CI <%{sender}>
To: %{recipient}
MIME-Version: 1.0
Content-type: text/html; charset=utf-8
Subject: [%{succeeded}] %{name} (%{revision})

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta content="text/html; charset="UTF-8" http-equiv="Content-Type"/>
  </head>
  <body>
    <div style="font-weight: bold; color: #444; margin: 15px;">%{name}&nbsp;&nbsp;-&nbsp;&nbsp;%{time}</div>
    <div style="width: 650px; border-radius: 5px; box-shadow: #eee 2px 2px 3px 3px; margin: auto 0; padding: 5px; border: 1px solid black;">
%{message}    </div>
  </body>
</html>
eos
	:header => "      <div style=\"text-align: center; font-weight: bold; margin-bottom: 15px;\" align=\"center\">Build took %{time} seconds.</div>\n",
	:project => "      <span style=\"color: %{color};\">Project %{name} (%{time} s) %{success}</span>"
}

SMTP = CONFIG["email"]["smtp"] or nil

add_action("email") do |build, action|
	raise "You have to provide email settings" unless SMTP

	sender = SMTP["force_email"] if SMTP.has_key? "force_email"
	sender = action["sender"] if not SMTP.has_key? "force_email" and action.has_key? "sender"
	raise "You need a sender" unless sender and action.has_key? "recipient"
	
	message = BASE_MAIL[:header] % { :time => build.analytics[:TotalTime].round(2) }

	build.analytics[:Projects].each do |project, data|
		message += BASE_MAIL[:project] % { :color => data[:Success] ? "#070" : "#700", :name => project, :time => data[:Time].round(2), :success => data[:Success] ? "Succeeded" : "Failed" }
		
		useful = { :Warnings => 0, :Errors => 0, :ErrorMessages => [] }
		last_useful = { :Warnings => 0, :Errors => 0 } if build.last_analytics
		data[:Messages].each do |msg|
			useful[:Warnings] = useful[:Warnings] + 1 if msg[:Type] == "warning"
			useful[:Errors] = useful[:Errors] + 1 if msg[:Type] == "error"
			useful[:ErrorMessages] << "#{msg[:File]}#{(msg[:Line] ? "(#{msg[:Line]})" : "")}: #{msg[:Message]}" if msg[:Type] == "error"
		end
		build.last_analytics["Projects"][project]["Messages"].each do |msg|
			last_useful[:Warnings] = last_useful[:Warnings] + 1 if msg["Type"] == "warning"
			last_useful[:Errors] = last_useful[:Errors] + 1 if msg["Type"] == "error"
		end if build.last_analytics and build.last_analytics["Projects"].has_key? project

		warnings = useful[:Warnings]
		errors = useful[:Errors]
		warningDelta = 0
		errorDelta = 0
		warningDelta = warnings - last_useful[:Warnings] if last_useful
		errorDelta = errors - last_useful[:Errors] if last_useful

		warningDisp = (warnings > 0 or warningDelta != 0)
		errorDisp = (errors > 0 or errorDelta != 0)

		if warningDisp or errorDisp then
			message += "<span style=\"float: right; text-align: right;\">With"
			message += " #{useful[:Warnings]} warning#{useful[:Warnings] == 1 ? "" : "s"}" if warningDisp
			message += "(#{warningDelta > 0 ? "<span style=\"color: #f22;\">+" : "<span style=\"color: #2f2;\">-"}#{warningDelta.abs}</span>)" if warningDelta != 0
			message += " and" if warningDisp and errorDisp
			message += " #{useful[:Errors]} error#{useful[:Errors] == 1 ? "" : "s"}" if errorDisp
			message += "(#{errorDelta > 0 ? "<span style=\"color: #f22;\">+" : "<span style=\"color: #2f2;\">-"}#{errorDelta.abs}</span>)" if errorDelta != 0
			message += "</span>"
		end

		message += "<br/>\n"

		unless useful[:ErrorMessages].empty? then
			message += "      <ul style=\"font-size: 10pt; padding-left: 20px; margin-top: 2px;\">\n"
			useful[:ErrorMessages].each do |err| message += "        <li>#{err}</li>\n" end
			message += "      </ul>\n"
		end
	end

	email_message = BASE_MAIL[:message] % {
		:sender => sender, :recipient => action["recipient"], :revision => build.revision,
		:succeeded => build.succeeded ? (build.last_succeeded ? "Succeeded" : "Fixed") : (build.last_succeeded ? "Broken" : "Still Failing"),
		:name => build.name, :time => Time.now, :message => message
	}

	connection = Net::SMTP.new(SMTP["host"], SMTP["port"])
	connection.enable_ssl

	connection.start(SMTP["helo"], SMTP["user"], SMTP["password"], :plain) do |smtp|
		smtp.send_message email_message, sender, action["recipient"]
	end
end
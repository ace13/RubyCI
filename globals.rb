require 'psych'

CONFIG = Psych.load(open(File.expand_path(File.dirname(__FILE__)) + "/config.yml").read)
VERBOSE = nil

module OS
    def OS.windows?
        (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def OS.mac?
        (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def OS.unix?
        !OS.windows?
    end

    def OS.linux?
        OS.unix? and not OS.mac?
    end

    def OS.name?
        return "windows" if OS.windows?
        return "linux" if OS.linux?
        return "mac" if OS.mac?
    end
end

class String
    def colorize(color_code)
        return self if OS.windows? # ANSI escape codes no work on Windows
        "\e[#{color_code}m#{self}\e[0m"
    end

    def red
        colorize(31)
    end

    def green
        colorize(32)
    end

    def yellow
        colorize(33)
    end

    def pure_string
        temp = self.clone
        loop{ temp[/\033\[\d+m/] = "" } # Remove ANSI escape codes
        rescue IndexError
            return temp
    end
end

def puts_right(pos, string) 
    columns = ENV["COLUMNS"]
    columns = 80 unless columns
    width = (pos % columns) + string.pure_string.length # Don't count ANSI escape codes
    width = (width % columns) if width > columns
    print " " * (columns - width)
    puts string
end

#!/usr/bin/ruby
#
# == Synopsis
# Simple nagios plugin to check the status of an Adobe Flash Policy
# server
#
# == Usage
# check_flashpolicy --host HOSTNAME [--timeout TIMEOUT ]
#
# --host HOSTNAME
#   The server to check
#
# --timeout TIMEOUT
#   How long to wait to complete the transaction before assuming its critical. Default 5 seconds
#
# --help
#   Show this help
#
# == Author
# R.I.Pienaar <rip@devco.net>

require 'socket'
require 'timeout'
require 'getoptlong'

opts = GetoptLong.new(
	[ '--host', GetoptLong::REQUIRED_ARGUMENT],
	[ '--timeout', '-t', GetoptLong::OPTIONAL_ARGUMENT],
	[ '--help', '-h', GetoptLong::NO_ARGUMENT]
)

timeout = 5
hostname = false

def showhelp
	begin
		require 'rdoc/ri/ri_paths'
		require 'rdoc/usage'
		RDoc::usage
	rescue Exception => e
		puts("Install RDoc::usage or view the comments in the top of the script to get detailed help")
	end
end

opts.each { |opt, arg|
	case opt
	when '--help'
		showhelp	
		exit
	when '--host'
		hostname = arg
	when '--timeout'
		timeout = arg
	end
}

unless hostname
	showhelp
	exit
end

starttime = Time.new

begin
	timeout(timeout.to_i) do
		t = TCPSocket.new(hostname, "843")
		t.print("<policy-file-request/>\000")

		answer = t.gets()
		if answer.match(/xml version=/)
			puts("OK: Got XML response in #{Time.new - starttime} seconds")
		else 
			raise("Got unexpected resonse: #{answer}")
		end

		t.close
	end
rescue Timeout::Error
	puts("CRITICAL: #{timeout} seconds TIMEOUT exceeded");
	exit(2)
rescue Exception => e
	puts("CRITICAL: Unexpeced exception: #{e.message}")
	exit(2)
end

exit(0)

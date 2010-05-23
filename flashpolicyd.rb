#!/usr/bin/ruby
# == Synopsis
#
# flashpolicyd: Serve Adobe Flash Policy XML files to clients
#
# == Description
# Server to serve up flash policy xml files for flash clients since
# player version 9,0,124,0. (Player 9 update 3)
#
# See http://www.adobe.com/devnet/flashplayer/articles/fplayer9_security_04.html
# for more information, this needs to run as root since it should listen on 
# port 843 which on a unix machine needs root to listen on that socket.
#
# == Signals
# * USR1 signal prints a single line stat message, during
#   normal running this stat will be printed every 30 minutes by default, settable
#   using --logfreq
# * USR2 signal dumps the current threads and their statusses 
# * HUP signal will toggle debug mode which will print more lines in the log file
# * TERM signal will exit the process closing all the sockets
#
# == Usage
# flashpolicyd [OPTIONS]
#
# --help, -h:
#   Show Help
#
# --verbose
#   Turns on verbose logging to log file - can also be turned on and off at runtime using -HUP signals
#
# --xml
#   XML File to Serve to clients, read at startup only
# 
# --timeout, -t
#   If a request does not complete within this time, close the socket,
#   default is 10 seconds
#
# --logfreq, -l
#   How often to log stats to log file, default 1800 seconds
#
# --logfile
#   Where to write log lines too
#
# --user
#   Drops privileges after binding to the socket to this user
#
# --port
#   What port to listen on 843 by default
#
# == Download and Further Information
# Latest versions, installation documentation and other related info can be found
# at http://code.google.com/p/flashpolicyd
#
# == License 
# Released under the terms of the GPLv2, see the include COPYING file for full text of 
# this license.
#
# == Author
# R.I.Pienaar <rip@devco.net>

require "socket"
require "logger"
require "ostruct"
require "thread"
require "timeout"
require 'getoptlong'

opts = GetoptLong.new(
    [ '--xml', GetoptLong::REQUIRED_ARGUMENT],
    [ '--verbose', '-v', GetoptLong::NO_ARGUMENT],
    [ '--timeout', '-t', GetoptLong::OPTIONAL_ARGUMENT],
    [ '--logfreq', '-l', GetoptLong::OPTIONAL_ARGUMENT],
    [ '--user', '-u', GetoptLong::OPTIONAL_ARGUMENT],
    [ '--logfile', GetoptLong::REQUIRED_ARGUMENT],
    [ '--port', GetoptLong::REQUIRED_ARGUMENT],
    [ '--help', '-h', GetoptLong::NO_ARGUMENT]
)

# defaults before parsing command line
@verbose = false
@xmldata = ""
@timeout = 10
@logfreq = 1800
@port = 843
xmlfile = ""
logfile = ""
user = ""

opts.each { |opt, arg|
  case opt
    when '--help'
      begin
        require 'rdoc/ri/ri_paths'
        require 'rdoc/usage'
        RDoc::usage
      rescue Exception => e
        puts("Install RDoc::usage or view the comments in the top of the script to get detailed help")
      end

      exit
    when '--xml'
      xmlfile = arg
    when '--user'
      user = arg
    when '--verbose'
      @verbose = true
    when '--maxclients'
      @maxclients = arg
    when '--logfreq'
      @logfreq = arg
    when '--timeout'
      @timeout = arg
    when '--port'
      @port = arg.to_i
    when '--logfile'
      logfile = arg
  end
}

# Read the xml data into a string
if (xmlfile.length > 0 and File.exists?(xmlfile))
  begin
    @xmldata = IO.read(xmlfile)
  rescue Exception => e
    puts "Got exception #{e.class} #{e} while reading #{xmlfile}"
    exit
  end
else
  puts("Pass the path to the xml file to serve using --xml, see --help for detailed help")
  exit
end

# create a logger keeping 10 files of 1MB each
begin
  @logger = Logger.new(logfile, 10, 102400)
rescue Exception => e
  puts("Got #{e.class} #{e} while attempting to create logfile #{logfile}")
  exit
end


class PolicyServer
  # Generic logging method that takes a severity constant from the Logger class such as Logger::DEBUG
  def log(severity, msg)
    @logger.add(severity) { "#{Thread.current.object_id}: #{msg}" }
  end
  
  # Log a msg at level INFO
  def info(msg)
    log(Logger::INFO, msg)
  end
  
  # Log a msg at level WARN
  def warn(msg)
    log(Logger::WARN, msg)
  end
  
  # Log a msg at level DEBUG
  def debug(msg)
    log(Logger::DEBUG, msg)
  end
  
  # Log a msg at level FATAL
  def fatal(msg)
    log(Logger::FATAL, msg)
  end
  
  # Log a msg at level ERROR
  def error(msg)
    log(Logger::ERROR, msg)
  end
  
  # === Synopsis
  # Initializes the server
  #
  # === Args
  # +port+::
  #   The port to listen on, if the port is < 1024 server must run as roo
  # +host+::
  #   The host to listen on, use 0.0.0.0 for all addresses
  # +xml+::
  #   The XML to serve to clients
  # +logger+::
  #   An instanse of the Ruby Standard Logger class
  # +timeout+::
  #   How long does client have to complete the whole process before the socket closes
  #   and the thread terminates
  # +debug+::
  #   Set to true to enable DEBUG level logging from startup
  def initialize(port, host, xml, logger, timeout=10, debug=false)
    @logger = logger
    @connections = []
    @@connMutex = Mutex.new
    @@clientsMutex = Mutex.new
    @@bogusclients = 0
    @@totalclients = 0
    @timeout = timeout
    @@starttime = Time.new
    @xml = xml
    @port = port
    @host = host

    if debug
      @logger.level = Logger::DEBUG
      debug("Starting in DEBUG mode")
    else
      @logger.level = Logger::INFO
    end
  end
  
  # If the logger instanse is in DEBUG mode, put it into INFO and vica versa
  def toggledebug
    if (@logger.debug?)
      @logger.level = Logger::INFO
      info("Set logging level to INFO")
    else
      @logger.level = Logger::DEBUG
      info("Set logging level to DEBUG")
    end
  end
  
  # Walks the list of active connections and dump them to the logger at INFO level
  def dumpconnections
    if (@connections.size == 0)
      info("No active connections to dump")
    else 
      connections = @connections
      
      info("Dumping current #{connections.size} connections:")
    
      connections.each{ |c|
        addr = c.addr
        info("#{c.thread.object_id} started at #{c.timecreated} currently in #{c.thread.status} status serving #{addr[2]} [#{addr[3]}]")
      }
    end
  end

  # Dump the current thread list
  def dumpthreads 
    Thread.list.each {|t|
      info("Thread: #{t.id} status #{t.status}")
    }
  end

  # Prints some basic stats about the server so far, bogus client are ones that timeout or otherwise cause problems
  def printstats
    u = sec2dhms(Time.new - @@starttime)
    
    info("Had #{@@totalclients} clients and #{@@bogusclients} bogus clients. Uptime #{u[0]} days #{u[1]} hours #{u[2]} min. #{@connections.size} connection(s) in use now.")
  end
  
  # Logs a message passed to it and increment the bogus client counter inside a mutex
  def bogusclient(msg, client)
    addr = client.addr
    
    warn("Client #{addr[2]} #{msg}")

    @@clientsMutex.synchronize {
      @@bogusclients += 1
    }
  end
  
  # The main logic of client handling, waits for @timeout seconds to receive a null terminated
  # request containing "policy-file-request" and sends back the data, else marks the client as
  # bogus and close the connection.
  #
  # Any exception caught during this should mark a client as bogus
  def serve(connection)
    client = connection.client
        
    # Flash clients send a null terminate request
    $/ = "\000"

    # run this in a timeout block, clients will have --timeout seconds to complete the transaction or go away
    begin
      timeout(@timeout.to_i) do
        loop do
          request = client.gets

          if request =~ /policy-file-request/
            client.puts(@xml)
            
            debug("Sent xml data to client")
            break
          end
        end
      end
    rescue Timeout::Error
      bogusclient("connection timed out after #{@timeout} seconds", connection)
    rescue Errno::ENOTCONN => e
      warn("Unexpected disconnection while handling request")
    rescue Errno::ECONNRESET => e
      warn("Connection reset by peer")
    rescue Exception => e
      bogusclient("Unexpected #{e.class} exception: #{e}", connection)
    end
  end
  
  # === Synopsis
  # Starts the main loop of the server and handles connections, logic is more or less:
  # 
  # 1. Opens the port for listening
  # 1. Create a new thread so the connection handling happens seperate from the main loop
  # 1. Create a loop to accept new sessions from the socket, each new sesison gets a new thread
  # 1. Increment the totalclient variable for stats handling
  # 1. Create a OpenStruct structure with detail about the current connection and put it in the @connections array
  # 1. Pass the connection to the serve method for handling 
  # 1. Once handling completes, remove the connection from the active list and close the socket
  def start
    begin
      # Disable reverse lookups, makes it all slow down
      BasicSocket::do_not_reverse_lookup=true
      server = TCPServer.new(@host, @port)
    rescue Exception => e
      fatal("Can't open server: #{e.class} #{e}")
      exit
    end
    
    begin
      @serverThread = Thread.new {
        while (session = server.accept)
          Thread.new(session) do |client| 
            begin 
              debug("Handling new connection from #{client.peeraddr[2]}, #{Thread.list.size} total threads ")

              @@clientsMutex.synchronize {
                @@totalclients += 1
              }

              connection = OpenStruct.new
              connection.client = client
              connection.timecreated = Time.new
              connection.thread = Thread.current
              connection.addr = client.peeraddr
          
              @@connMutex.synchronize {
                @connections << connection
                debug("Pushed connection thread to @connections, now #{@connections.size} connections")
              }
              
              debug("Calling serve on connection")
              serve(connection)
          
              client.close
          
              @@connMutex.synchronize {
                @connections.delete(connection)
                debug("Removed connection from @connections, now #{@connections.size} connections")
              }
          
            rescue Errno::ENOTCONN => e
              warn("Unexpected disconnection while handling request")
            rescue Errno::ECONNRESET => e
              warn("Connection reset by peer")
            rescue Exception => e
              error("Unexpected #{e.class} exception while handling client connection: #{e}")
              error("Unexpected #{e.class} exception while handling client connection: #{e.backtrace.join("\n")}")
              client.close
            end # block around main logic 
          end # while
        end # around Thread.new for client connections
      } # @serverThread
    rescue Exception => e
      fatal("Got #{e.class} exception in main listening thread: #{e}")
    end
  end    
end

# Goes into the background, chdir's to /tmp, and redirect all input/output to null
# Beginning Ruby p. 489-490
def daemonize
  fork do
    Process.setsid
    exit if fork
    Dir.chdir('/tmp')
    STDIN.reopen('/dev/null')
    STDOUT.reopen('/dev/null', 'a')
    STDERR.reopen('/dev/null', 'a')

    trap("TERM") { 
      @logger.debug("Caught TERM signal") 
      exit
    }
    yield
  end
end

# Returns an array of days, hrs, mins and seconds given a second figure
# The Ruby Way - Page 227
def sec2dhms(secs)
  time = secs.round
  sec = time % 60
  time /= 60
  
  mins = time % 60
  time /= 60

  hrs = time % 24
  time /= 24

  days = time
  [days, hrs, mins, sec]
end

# Go into the background and initalizes the server, sets up some signal handlers and print stats
# every @logfreq seconds, any exceptions gets logged and exits the server
daemonize do
  begin
    @logger.info("Starting server on port #{@port} in process #{$$}")
    
    server = PolicyServer.new(@port, "0.0.0.0", @xmldata, @logger, @timeout, @verbose)
    server.start

   # change user after binding to port
   if user.length > 0
        require 'etc'
        uid = Etc.getpwnam(user).uid
        gid = Etc.getpwnam(user).gid
        # Change process ownership
        Process.initgroups(user, gid)
        Process::GID.change_privilege(gid)
        Process::UID.change_privilege(uid)
    end

    # Send HUP to toggle debug mode or not for a running server
    trap("HUP") {
      server.toggledebug
    }    

    # send a USR1 signal for a full connection list dump
    trap("USR1") { 
      server.dumpconnections 
      server.printstats
    }
    
    # Send USR2 to dump all threads
    trap("USR2") {
      server.dumpthreads
    }
    
    # Cycle and print stats every now and then
    loop do
      sleep @logfreq.to_i
      server.printstats
    end
  rescue SystemExit => e
    @logger.fatal("Shutting down main daemon thread due to: #{e.class} #{e}")
  rescue Exception => e
    @logger.fatal("Unexpected exception #{e.class} from main loop: #{e}")
    @logger.fatal("Unexpected exception #{e.class} from main loop: #{e.backtrace.join("\n")}")
  end
  
  @logger.info("Server process #{$$} shutting down")
end

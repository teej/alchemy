module AlchemyServer

  ##
  # This is an internal class that's used by Alchemy::Server to handle the
  # Memcached protocol and act as an interface between the Server and the
  # Recipes.
  
  class Handler < EventMachine::Connection

    ACCEPTED_COMMANDS = ["set", "add", "replace", "append", "prepend", "get", "delete", "flush_all", "version", "verbosity", "quit", "stats"].freeze
    
    # ERRORs
    ERR_UNKNOWN_COMMAND   = "ERROR\r\n".freeze
    ERR_BAD_CLIENT_FORMAT = "CLIENT_ERROR bad command line format\r\n".freeze
    ERR_SERVER_ISSUE      = "SERVER_ERROR %s\r\n"

    # GET
    GET_COMMAND         = /\Aget (.{1,250})\s*\r\n/m
    GET_RESPONSE        = "VALUE %s %s %s\r\n%s\r\nEND\r\n".freeze
    GET_RESPONSE_EMPTY  = "END\r\n".freeze

    # SET
    SET_COMMAND           = /\A(\w+) (.{1,250}) ([0-9]+) ([0-9]+) ([0-9]+)\r\n/m
    SET_RESPONSE_SUCCESS  = "STORED\r\n".freeze
    SET_RESPONSE_FAILURE  = "NOT STORED\r\n".freeze
    SET_CLIENT_DATA_ERROR = "CLIENT_ERROR bad data chunk\r\nERROR\r\n".freeze
    
    # DELETE
    DELETE_COMMAND            = /\Adelete (.{1,250})\s?([0-9]*)\r\n/m
    DELETE_RESPONSE_SUCCESS   = "DELETED\r\n".freeze
    DELETE_RESPONSE_FAILURE   = "NOT_FOUND\r\n".freeze
    
    # FLUSH
    FLUSH_COMMAND   = /\Aflush_all\s?([0-9]*)\r\n/m
    FLUSH_RESPONSE  = "OK\r\n".freeze
    
    # VERSION
    VERSION_COMMAND   = /\Aversion\r\n/m
    VERSION_RESPONSE  = "VERSION #{VERSION}\r\n".freeze
    
    # VERBOSITY
    VERBOSITY_COMMAND   = /\Averbosity\r\n/m
    VERBOSITY_RESPONSE  = "OK\r\n".freeze
    
    # QUIT
    QUIT_COMMAND   = /\Aquit\r\n/m
    
    # STAT Response
    STATS_COMMAND   = /\Astats\r\n/m
    STATS_RESPONSE  = "STAT pid %d
STAT uptime %d
STAT time %d
STAT version %s
STAT rusage_user %0.6f
STAT rusage_system %0.6f
STAT curr_items %d
STAT total_items %d
STAT bytes %d
STAT curr_connections %d
STAT total_connections %d
STAT cmd_get %d
STAT cmd_set %d
STAT get_hits %d
STAT get_misses %d
STAT bytes_read %d
STAT bytes_written %d
STAT limit_maxbytes %d
%sEND\r\n".freeze
    LIST_STATS_RESPONSE = "STAT list_%s_items %d
STAT list_%s_total_items %d
STAT list_%s_logsize %d
STAT list_%s_expired_items %d\n".freeze

    ##
    # Creates a new handler for the MemCache protocol that communicates with a
    # given client.

    def initialize(options = {})
      @opts = options
    end

    ##
    # Process incoming commands from the attached client.

    def post_init
      @server = @opts[:server]
      @expiry_stats = Hash.new(0)
      @expected_length = nil
      @server.stats[:total_connections] += 1
      set_comm_inactivity_timeout @opts[:timeout]
      @list_collection = @opts[:list]
    end
    
    def receive_data(incoming)
      data = incoming
      
      ## Reject request if command isn't recognized
      if !ACCEPTED_COMMANDS.include?(data.split(" ").first)
        response = respond ERR_UNKNOWN_COMMAND
      elsif request_line = data.slice!(/.*?\r\n/m)
        response = process(request_line, data)
      else
        response = respond ERR_BAD_CLIENT_FORMAT
      end
      
      if response
        send_data response
      end
    end

    def process(request, data)
      case request
        when SET_COMMAND
          set($1, $2, $3, $4, $5.to_i, data)
        when GET_COMMAND
          get($1)
        when STATS_COMMAND
          stats
        when DELETE_COMMAND
          delete($1)
        when FLUSH_COMMAND
          flush_all
        when VERSION_COMMAND
          respond VERSION_RESPONSE
        when VERBOSITY_COMMAND
          respond VERBOSITY_RESPONSE
        when QUIT_COMMAND
          close_connection
          nil
        else
          logger.warn "Bad Format: #{data}."
          respond ERR_BAD_CLIENT_FORMAT
      end
      rescue => e
        logger.error "Error handling request: #{e}."
        logger.debug e.backtrace.join("\n")
        respond ERR_SERVER_ISSUE, e.to_s
    end

  private
    def respond(str, *args)
      response = sprintf(str, *args)
      @server.stats[:bytes_written] += response.length
      response
    end
    
    def set(command, key, flags, expiry, expected_data_size, data)
      data = data.to_s
      respond SET_RESPONSE_FAILURE unless (data.size == expected_data_size + 2)
      data = data[0...expected_data_size]
      
      if @list_collection.send(command.to_sym, key, data)
        respond SET_RESPONSE_SUCCESS
      else
        respond SET_RESPONSE_FAILURE
      end
    end
    
    def get(key)
      key = key.strip
      if data = @list_collection.get(key)
        respond GET_RESPONSE, key, 0, data.size, data
      else
        respond GET_RESPONSE_EMPTY
      end
    end
      
    def delete(key)
      if @list_collection.delete(key)
        respond DELETE_RESPONSE_SUCCESS
      else
        respond DELETE_RESPONSE_FAILURE
      end
    end
    
    def flush_all
      @list_collection.flush_all
      respond FLUSH_RESPONSE
    end
    
    def stats
      respond STATS_RESPONSE, 
        Process.pid, # pid
        Time.now - @server.stats(:start_time), # uptime
        Time.now.to_i, # time
        AlchemyServer::VERSION, # version
        Process.times.utime, # rusage_user
        Process.times.stime, # rusage_system
        @list_collection.stats(:current_size), # curr_items
        @list_collection.stats(:total_items), # total_items
        @list_collection.stats(:current_bytes), # bytes
        @server.stats(:connections), # curr_connections
        @server.stats(:total_connections), # total_connections
        @server.stats(:get_requests), # get count
        @server.stats(:set_requests), # set count
        @list_collection.stats(:get_hits),
        @list_collection.stats(:get_misses),
        @server.stats(:bytes_read), # total bytes read
        @server.stats(:bytes_written), # total bytes written
        0, # limit_maxbytes
        list_stats
    end
  
    def list_stats
      @list_collection.lists.inject("") do |m,(k,v)|
        m + sprintf(LIST_STATS_RESPONSE,
                      k, v.length,
                      k, v.total_items,
                      k, v.logsize,
                      k, @expiry_stats[k])
      end
    end

    def logger
      @server.logger
    end
  end
end

require 'socket'
require 'logger'

module Minister

  class Twitch  
    attr_reader :socket, :logger, :running

    def initialize(logger = nil)
      @logger = logger || Logger.new(STDOUT)
      @running = false
      @socket = nil
    end

    def initialize_server
      @socket = TCPSocket.new("#{ENV['TWITCH_CHAT_SERVER']}", ENV['TWITCH_CHAT_SERVER_PORT'])
      login
      @logger.info 'Connected...'
    end
    
    def run
      @running = true
      ready = IO.select([@socket])

      ready[0].each do |s|
        line = s.gets.chomp
        @logger.info "> #{line}" 

        if line.match(/^PING :(.*)$/)
          sendRaw "PONG #{$~[1]}"
          next
        end
        
        match = line.match(/:(.+)!.+PRIVMSG #(.+) :(.+)$/)
        message = match && match[3]

        if message =~ /^!hello$/
          sendMsg("Greetings and Salutations #{match[1]}, you are a big meat sack!!", match[2])
        end        
      end
    end

    def start 
      @logger.info "Initializing channel #{self.inspect}..."
      @running =true
      initialize_server
      Thread.start do
        while (running) do
          run  
        end
      end
    end

    def stop
      @logger.info "Closing  twitch bot"
      part(ENV['TWITCH_CHAT_CHANNEL'])
      sendRaw("QUIT")
      @socket.close
      @running = false
    end
    
    def sendRaw(message)
      # Do not log passwords
      if message =~ /^PASS/
        @logger.info "< PASS XXXXXXXXXXXXXX"
      else
        @logger.info "< #{message}"
      end
      @socket.puts(message)
    end

    def sendMsg(message, channel)
      sendRaw("PRIVMSG ##{channel} :#{message}")
    end

    def join(channel)
      sendRaw("JOIN ##{channel}")
    end

    def part(channel)
      sendRaw("PART ##{channel}")
    end  


    private

    def login
      username = Minister.config.settings['twitch']['username']
      
      @logger.info "Perparing to connect to Twitch Chat Server (#{ENV['TWITCH_CHAT_SERVER']}) as #{username} ..."
      #sendRaw("PASS #{ENV['TWITCH_CHAT_TOKEN']}")
      sendRaw("PASS #{Minister.config.settings['twitch']['token']}")
      sendRaw("NICK #{username}") 
    end

  end
end



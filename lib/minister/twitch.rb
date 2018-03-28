require 'socket'
require 'logger'

module Minister
class Twitch < Server 
  attr_reader :socket

  def initialize(*args)
    super
    @socket = nil
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

  def run
    @running = true
    ready = IO.select([@socket])

    ready[0].each do |s|
      line = s.gets.chomp
      @logger.info "> #{line}" 

      match = line.match(/:(.+)!.+PRIVMSG #(.+) :(.+)$/)
      message = match && match[3]

      if message =~ /^!hello$/
        sendMsg("Greetings and Salutations #{match[1]}, you are a big meat sack!!", match[2])
      end        
    end
  end

  def initialize_server
    @socket = TCPSocket.new("#{ENV['TWITCH_CHAT_SERVER']}", ENV['TWITCH_CHAT_SERVER_PORT'])
    login
    @logger.info 'Connected...'
  end
  
  def stop
    @logger.info "Closing  twitch bot"
    @socket.close
    @running = false
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



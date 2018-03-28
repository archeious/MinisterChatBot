require 'socket'
require 'logger'

Thread.abort_on_exception = true

class Twitch
  attr_reader :logger, :running, :socket

  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @running = false
    @socket = nil
  end
  
  def sendRaw(message)
    @logger.info "< #{message}"
    @socket.puts(message)
  end

  def sendMsg(message, channel)
    sendRaw("PRIVMSG ##{channel} :#{message}")
  end

  def run
    @logger.info "Perparing to connect to #{ENV['TWITCH_CHAT_SERVER']}..."
    @socket = TCPSocket.new("#{ENV['TWITCH_CHAT_SERVER']}", ENV['TWITCH_CHAT_SERVER_PORT'])
    @running = true
    sendRaw("PASS #{ENV['TWITCH_CHAT_TOKEN']}")
    sendRaw("NICK #{ENV['TWITCH_CHAT_USER']}")
    sendRaw("JOIN #{ENV['TWITCH_CHAT_CHANNEL']}")
    @logger.info 'Connected...'
    Thread.start do
      while  (running) do
        ready = IO.select([@socket])

        ready[0].each do |s|
          line = s.gets.chomp
          @logger.info line 

          match = line.match(/:(.+)!.+PRIVMSG #(.+) :(.+)$/)
          message = match && match[3]

          if message =~ /^!hello$/
            sendMsg("Greetings and Salutations #{match[1]}, you are a big meat sack!!", match[2])
          end        
 
        end
      end
    end
  end

  def stop
    @logger.info "Closing  twitch bot"
    @socket.close
    @running = false
  end

end


bot = Twitch.new
bot.run

while (bot.running) do
  command = gets.chomp

  if command == 'quit'
    bot.stop
  else
    bot.send(command)
  end
end

bot.logger.info "Quitting."

require 'socket'
require 'logger'
require "google_drive"

module Minister

  class Twitch  
    attr_reader :socket, :logger, :running

    def initialize(logger = nil)
      #@logger       = logger || Logger.new('irc.log')
      @logger       = logger || Logger.new(STDOUT)
      @running      = false
      @socket       = nil
      @command_list = []
      @google_session = GoogleDrive::Session.from_config("config/config.json")
      @twitch_caps  = []
    end

    def initialize_server
      @socket = TCPSocket.new("#{ENV['TWITCH_CHAT_SERVER']}", ENV['TWITCH_CHAT_SERVER_PORT'])
      login
      @logger.info 'Connected...'
    end

    def parse_raw_irc(str)
      resp = {} 
      
      if str.match(/^:tmi.twitch.tv (.*)$/)
        resp["type"] = "SRVMSG"
        resp["msg"] = $~[1]
        return resp
      end

      if str.match(/^:botofarch.tmi.twitch.tv (.*)$/)
        resp["type"] = "USRMSG"
        resp["msg"] = $~[1]
        return resp
      end
     
      info = str.match(/:(?<user>.+)!.+ (?<cmd>.+) #(?<chan>.+) :(?<msg>.+)$/)
      resp["type"] = "BASIC"
      resp["cmd"]  = info && info["cmd"]
      resp["user"] = info && info["user"]
      resp["chan"] = info && info["chan"]
      resp["msg"]  = info && info["msg"]
      
#      if @twitch_caps.include? 'tags'
#        preamble = str.match(/^(.*?):/)
#        puts preamble
#      end  
      resp
    end

    def topGamesCommand(sheet_id, channel)
      # ws = @google_session.spreadsheet_by_key("1xZ0LVo8Hxx3cnBzbjMG_pCai9lmeWP8RhDsK4WrTF8Q").worksheets[0]
      ws = @google_session.spreadsheet_by_key(sheet_id).worksheets[0]
      count = Minister.config.settings['command']['topgames']['count']
      if ws.kind_of?(Array) && ws.length < count
        count = ws.length
      end
  
      msg = "The current top contenders are: "

      for n in 1..count-1
        msg += "#{ws.rows[n][1]} (#{ws.rows[n][5]}), "
      end
        msg += " and #{ws.rows[n][1]} (#{ws.rows[n][5]})."
      sendMsg("#{msg}", channel)
      ws[1, 1] = "1"
      ws.save
    end
    
    def run
      @running = true
      ready = IO.select([@socket])

      ready[0].each do |s|
        line = s.gets.chomp
        @logger.info "> #{line}" 

        #Process Twitch Commands
        
        #Keep the connect alive via ping/pong https://dev.twitch.tv/docs/irc/#connecting-to-twitch-irc
        if line.match(/^PING :(.*)$/)
          sendRaw "PONG #{$~[1]}"
          next
        end

        if line.match(/^:tmi.twitch.tv CAP \* ACK :twitch.tv\/(\w+)$/)
          acked_cap = $~[1]
          if @twitch_caps.include? acked_cap
            @logger.error "ERR: Twitch Capability #{acked_cap} with already acknowledged"
            next
          else  
            @twitch_caps << acked_cap
            next
          end
        end

        info = parse_raw_irc(line)

        msg  = info && info["msg"]
        user = info && info["user"]
        chan = info && info["chan"]

        if info["type"] == "BASIC" and info["cmd"] == "PRIVMSG"
          if msg && msg.match(/^!/)
            cmd = msg.match(/^!([\w]+)/)[0]
            case cmd
            when '!hello'
              sendMsg("Greetings and Salutations #{user}, you are a big meat sack!!", chan)
            when '!top'
              topGamesCommand(Minister.config.settings['command']['topgames']['worksheet'], chan)
            else
              #sendMsg("Unknown Command \"#{cmd}\"",chan)
            end
          else
            puts "#{info["cmd"]} - #{info["user"]} : #{info["msg"]}" 
          end
        else
          puts "#{info["cmd"]} - #{info["user"]} : #{info["msg"]}"  
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
      sendRaw("CAP REQ :twitch.tv/tags") 
      sendRaw("CAP REQ :twitch.tv/commands")
    end

  end
end



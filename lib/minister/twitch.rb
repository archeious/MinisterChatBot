require 'socket'
require 'logger'
require "google_drive"

module Minister

  class Twitch  
    attr_reader :socket, :logger, :running

    def initialize(logger = nil)
      #file = File.open(STDOUT)
      @logger       = logger || Logger.new('irc.log')
      @running      = false
      @socket       = nil
      @command_list = []
      @google_session = GoogleDrive::Session.from_config("config/config.json")
    end

    def initialize_server
      @socket = TCPSocket.new("#{ENV['TWITCH_CHAT_SERVER']}", ENV['TWITCH_CHAT_SERVER_PORT'])
      login
      @logger.info 'Connected...'
    end

    def parse_input(str) 
        info = str.match(/:(?<user>.+)!.+PRIVMSG #(?<chan>.+) :(?<msg>.+)$/)
        info
    end

    def topGamesCommand(sheet_id, channel)
      # ws = @google_session.spreadsheet_by_key("1xZ0LVo8Hxx3cnBzbjMG_pCai9lmeWP8RhDsK4WrTF8Q").worksheets[0]
      ws = @google_session.spreadsheet_by_key(sheet_id).worksheets[0]
      count = Minister.config.settings['command']['topgames']['count']
      logger.debug "Worksheet is #{count} rows in length"
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
      #ws.rows.each { |row|
      #  p row[1] + " (" + row[5] +")" if row[5].to_i > 0
      #}
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
        
        info = parse_input(line)

        msg  = info && info["msg"]
        user = info && info["user"]
        chan = info && info["chan"]

        if msg && msg.match(/^!/)
          cmd = msg.match(/^!([\w]+)/)[0]
          logger.debug "COMMAND: #{cmd}"
          case cmd
          when '!hello'
            sendMsg("Greetings and Salutations #{user}, you are a big meat sack!!", chan)
          when '!top'
            topGamesCommand(Minister.config.settings['command']['topgames']['worksheet'], chan)
          else
            sendMsg("Unknown Command \"#{cmd}\"",chan)
          end
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



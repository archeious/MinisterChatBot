require 'socket'
require 'logger'
require "google_drive"
require 'time'
require 'minister/operation/voting'

module Minister

  class Twitch  
    attr_reader :socket, :logger, :running

    def initialize(logger = nil)
      #@logger       = logger || Logger.new('irc.log')
      @logger       = logger || Logger.new(STDOUT)
      @running      = false
      @socket       = nil
      @command_list = []
      @twitch_caps  = []
      @voting = Voting.new('1AMsnO3PLJoVZesrA1L64fM4I9_olUdvntf3c53snMts')
    end

    def initialize_server
      @socket = TCPSocket.new("#{ENV['TWITCH_CHAT_SERVER']}", ENV['TWITCH_CHAT_SERVER_PORT'])
      login
      @logger.info 'Connected...'
    end

    def parse_irc_tags(tags)      
      return tags.split(';')
    end

    def parse_irc_raw(input)
      resp = {}

      # If it is a PING command immediately bail out
      if input.match(/^PING :(.*)$/)
        resp[:command] = "PING"
        resp[:response] = $~[1]
        return resp
      end

      # Parse IRC tags if there are any and then strip them off the input line
      if input.match(/^@(.*?) (.*)/)
        resp[:tags] = parse_irc_tags($~[1])
        input = $~[2]
      end
      
      # Generic IRC input
      # :tmi.twitch.tv 001 botofarch :Welcome, GLHF!
      if input.match(/^:(.*)?tmi.twitch.tv (.+?) (.*)?$/)
        resp[:pre]     = $~[1]
        resp[:command] = $~[2]
        resp[:message] = $~[3]
        case resp[:command]
        when "PRIVMSG"
          resp[:user] = $~[1] if resp[:pre].length > 0 and resp[:pre].match(/^(.*)!.*$/)
          if resp[:message].length > 0 and resp[:message].match(/^#(.*)? :(.*)$/)
            resp[:channel] = $~[1] 
            resp[:message] = $~[2] 
          end
        end
        return resp
      end
      
      resp[:command] = "UNKNOWN #{input}"
      return resp
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

    def processBitDonation(user, amount, game = nil)
      ws = @google_session.spreadsheet_by_key('1AMsnO3PLJoVZesrA1L64fM4I9_olUdvntf3c53snMts').worksheets[1]
      nextRow = 1
      if ws.rows.kind_of?(Array) 
        nextRow = ws.rows.length + 1
      end

      puts "#{nextRow} update votes for #{game} by #{user} with #{amount} votes"
      ws[nextRow, 1] = Time.now.utc.iso8601
      ws[nextRow, 2] = user
      ws[nextRow, 3] = amount
      if game 
        ws[nextRow, 4] = game
      end
      ws.save
      ws.reload
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

        resp = parse_irc_raw(line)

        case resp[:command]
        when 'PRIVMSG'
          resp[:tags].each { |tag|
            if tag.match(/bits=(.+)/)
              amount = $~[1].to_f
              puts "BIT DONATION OF #{amount} TRIGGER ACTION"
              @voting.processBitDonation(resp[:user], amount, resp[:message])
            end 
          } if resp.has_key? :tags
          puts "#{resp[:user]} : #{resp[:message]}"
          if resp[:message].match(/^!(.+)?\b.*/)
            cmd = $~[1]
            #cmd = msg.match(/^!([\w]+)/)[0]
            case cmd
            when 'hello'
              sendMsg("Greetings and Salutations #{resp[:user]}, you are a big meat sack!!", resp[:channel])
            when 'top'
              topGamesCommand(Minister.config.settings['command']['topgames']['worksheet'], resp[:channel])
            end
          end
        when 'USERNOTICE'
          puts "USERNOTICE"
          resp[:tags].each { |tag|
            puts tag
            if tag.match(/msg-id=(.+)/)
             puts "msg-id=#{$~[1]}"
             if ["sub","resub","giftsub"].include? $~[1]
               puts "---SUBSCRIPTION---"
             end
            end
          } if resp.has_key? :tags         
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
      #sendRaw("PRIVMSG ##{channel} :#{message}")
      sendRaw("PRIVMSG #archeious :#{message}")
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



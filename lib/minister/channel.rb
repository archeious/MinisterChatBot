module Minister

  class Twitch  
    attr_reader :socket, :logger, :running

    def initialize()
      @logger = logger || Logger.new(STDOUT)
    end

  end

end

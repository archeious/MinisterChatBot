module Minister
    class Server 
      attr_reader :logger, :running
      def initialize(logger = nil)
        @logger = logger || Logger.new(STDOUT)
        @running = false
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

      def join(channel)
        raise NotImplementedError.new('Subclasses must implement nbehavior.')
      end

      def part(channel)
        raise NotImplementedError.new('Subclasses must implement nbehavior.')
      end

      private

      def initialize_server
        raise NotImplementedError.new('Subclasses must implement nbehavior.')
      end
   
      def run
        raise NotImplementedError.new('Subclasses must implement nbehavior.')
      end

    end
end

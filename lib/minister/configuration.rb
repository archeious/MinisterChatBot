require 'yaml'

module Minister

  class Configuration
    SETTINGS_FILE = Minister.root + '/config/settings.yaml'

    attr_reader :settings

    def initialize
      @settings = YAML.load_file(SETTINGS_FILE)
      @settings['twitch']['token'] = ENV['TWITCH_CHAT_TOKEN'] || @settings['twitch']['token']
    end

  end

end


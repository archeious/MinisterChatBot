module Minister
  def self.config
    @config || Configuration.new
  end

  def self.root
    @root || File.expand_path('../../',__FILE__)
  end
end

require 'minister/server'
require 'minister/configuration'
require 'minister/twitch'


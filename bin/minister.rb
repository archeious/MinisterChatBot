#!/usr/bin/env ruby

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'minister'

Thread.abort_on_exception = true


bot = Minister::Twitch.new
bot.run

while (bot.running) do
  command = gets.chomp

  if command == 'quit'
    bot.stop
  else
    bot.sendRaw(command)
  end
end


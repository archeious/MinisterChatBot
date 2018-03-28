#!/usr/bin/env ruby

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'minister'

Thread.abort_on_exception = true


srv  = Minister::Twitch.new
srv.start
srv.join(ENV['TWITCH_CHAT_CHANNEL'])

while (srv.running) do
  command = gets.chomp

  if command == 'quit'
    srv.stop
  else
    srv.sendRaw(command)
  end
end


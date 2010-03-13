#!/usr/bin/env ruby

require 'rubygems'
require 'httpclient'
require 'cgi'
require 'pp'

require 'file_names.rb'


client=HTTPClient.new
client.set_cookie_store(COOKIE_FN)

#Dump http traffic to the stderr
client.debug_dev=STDERR if ARGV.include? "-d"

resp=client.request(:get, "https://wave.google.com/wave/",[ [:nouacheck, nil]])
client.save_cookie_store()
client.cookie_manager.save_all_cookies(true) #HACK: client.save_cookie_store does not save "S" cookie!
File.open(WAVE_FN,"w") {|f| f.write(resp.body.content)}
puts "#{resp.status} #{resp.reason}" 
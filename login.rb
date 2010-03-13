#!/usr/bin/env ruby
require 'rubygems'
require 'highline/import'
require 'httpclient'
require 'cgi'
require 'pp'

require 'file_names.rb'

LOGIN_FN='.email'
APPLICATION_NAME="Http-Wave-Example-Client_0.1_by_ub"

def get_login(prompt="Enter google login (E-mail): ")
 
  default=nil
  if File.exist? LOGIN_FN then 
     default=File.read(LOGIN_FN)
  end
  login=ask(prompt) {|q| q.default=default if default
                         q.validate=/.+/}
  login.strip!
  if login !=default then 
    File.open(LOGIN_FN,"w"){|f| f.write(login)}
  end
  login
end  

def get_password(prompt="Enter Password: ")
   ask(prompt) {|q| q.echo = "*"}
end



class HTTPClient
  def reset_cookie_file
    File.open(COOKIE_FN, "w"){}
    self.set_cookie_store(COOKIE_FN)
  end
  
  
  def get_auth_token( login, password)
    resp=self.request(:post, 'https://www.google.com/accounts/ClientLogin',
                    [%w[service wave]],
                    {:accountType => 'GOOGLE',
                    :Email   => CGI.escape(login),
                    :Passwd  => CGI.escape(password),
                    :service => 'wave',
                    :source  => CGI.escape(APPLICATION_NAME)})
    return resp.status==200 ? resp.body.content[/Auth=(.*)/, 1] : 
                              [nil, resp.status, resp.reason]   
  end
end

login    = get_login()
password = get_password()

client=HTTPClient.new
client.reset_cookie_file 

client.debug_dev=STDERR if ARGV.include? "-d"

token, status, reason = client.get_auth_token( login, password)
unless token
  puts "#{status} #{reason}" 
else
  resp=client.request(:get, "https://wave.google.com/wave/",[ [:nouacheck, nil],[:auth, token]]) 
  client.save_cookie_store()
  puts "#{resp.status} #{resp.reason}" 
  pp resp.header["Location"]
end

               
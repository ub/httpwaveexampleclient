#!/usr/bin/env ruby

require 'rubygems'
require 'httpclient'
require 'cgi'
require 'ostruct'
require 'yaml'
require 'pp'

require 'file_names.rb'

require 'irb'

def read_global_vars
   jsvars=YAML.load_file JSVARS_FN
    $__fsd       = jsvars.__fsd  
    $__session   = jsvars.__session
    $__client_flags = jsvars.__client_flags 
end


class BrowserChannel
  CHANNEL_BASE_URI="https://wave.google.com/wave/wfe/channel"
  class AID
   attr_accessor :value
    def initialize
      @value=0      
    end
  end
 
  def getAID
    @aidwrap.value
  end
  
  def randomstring
    set=('a'..'z').to_a + ('0'..'9').to_a
    (0...12).map{ set[rand(set.length)] }.join
  end
  
  def initialize(aid_holder, sticky_session,debug_dev=nil)
    @gsessionid=sticky_session
    @aidwrap=aid_holder
    @client=HTTPClient.new
    @client.set_cookie_store(COOKIE_FN)
    @client.debug_dev=debug_dev

  end
  
end

class ForwardChannel < BrowserChannel
  def initialize(aid_holder, sticky_session, debug_dev=nil)
    @rid=rand(100_000)
    @sid=nil
    super(aid_holder, sticky_session,debug_dev)
  end
  
  def getSID
    initChannel unless @sid
    @sid
  end
                
  def getRID
      @rid+=1
  end
  
 
  def initChannel
    url_params=[
 #     [:gsessionid, @gsessionid],
      [:VER, 6],
      [:RID, getRID()], 
      [:CVER, 4], # CVER 4 works!
      [:zx, randomstring()],
      [:t, 1] 
    ]
    body_params=[[:count,0]]  
    resp=@client.request(:post,CHANNEL_BASE_URI,url_params,body_params)
    if resp.status==200
      @sid=resp.body.content[/"c","([^"]+)"/,1]
    end
    puts resp.body.content
  end
end

class BackChannel < BrowserChannel
  def initialize(aid_holder, sticky_session, channelSID,debug_dev)
    @sid=channelSID   
    super(aid_holder, sticky_session,debug_dev)
  end
  
  def request
      url_params=[
  #    [:gsessionid, @gsessionid],
      [:VER, 6],
      [:RID, 'rpc'], 
      [:SID, @sid],
      [:CI, 1],
      [:AID, getAID()],
      [:TYPE, 'xmlhttp'],
      [:zx, randomstring()],
      [:t, 1] 
    ]
       connection=@client.request_async(:get, CHANNEL_BASE_URI, url_params,nil,
                             'Connection'=>'keep-alive',
                             'Keep-Alive'=>'300' )  
       message=connection.pop
       @stream=message.content
       #pp message.header
       print message.status," ",message.reason
       puts
  end
  def response
    if @stream.eof? then return nil end
    n=@stream.readline.to_i
    m=@stream.read(n) if n>0
    m
  end
end


read_global_vars()
debug_dev = STDERR if ARGV.include? "-d"
sticky    = $__session[:sessionData][:sticky_session]
sessionid = $__session[:sessionData][:sessionid]

shared_aid_obj=BrowserChannel::AID.new
forward=ForwardChannel.new(shared_aid_obj, sticky, debug_dev)
forward.initChannel()
sid=forward.getSID
back=BackChannel.new(shared_aid_obj, sticky, sid, debug_dev)

loop do
back.request
loop do 
  m= back.response
  break if m.nil?
  puts "#{Time.now.strftime("%H:%M:%S")} #{m}"
end
end
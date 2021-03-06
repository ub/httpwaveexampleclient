#!/usr/bin/env ruby
#
#  talktowave.rb - WFE and BrowserChannel communication loop.
#                  Polls 'wfereqs' file and sends requests found
#                  there to the wave web server
#
#  this code is made available under the MIT License (see MIT-LICENSE.txt)
#  Copyright (c) 2010 Yuri Baranov <baranovu+gh@gmail.com>
#



$KCODE ='u'
require 'jcode'   # ruby 1.8
require 'rubygems'
require 'httpclient'
require 'cgi'
require 'ostruct'
require 'yaml'
require 'json'
require 'pp'


require 'file_names.rb'
require 'file_queue.rb'

#Monkey patch for Ruby 1.8
class IO 
  # Read length multibyte characters from the stream
  # Works when last expected character(s) of the string
  # are not multibyte
  def jread(length)
    buf=self.read(length)
    actual=buf.jlength
    
    while actual < length
      part=self.read(length-actual)
      if part then
	buf << part
	actual=buf.jlength
      else
	break
      end #if      
    end #while
    return buf
  end #def jread
end #class IO



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
    @ofs=0
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
      [:gsessionid, @gsessionid],
      [:VER, 8],
      [:RID, getRID()], 
      [:CVER, 4],
      [:zx, randomstring()],
      [:t, 1] 
    ]
    body_params=[[:count,0]]  
    resp=@client.request(:post,CHANNEL_BASE_URI,
                                url_params,body_params)
    if resp.status==200
      @sid=resp.body.content[/"c","([^"]+)"/,1]
    end
    puts resp.body.content
  end
  
  # maps is the name for outgoing requests in google's
  # browser channel comments
  def send_maps( *strings)
    count = strings.size
    body_params=[[:count, count],
                 [:ofs, @ofs    ]
                ]
    @ofs += count
    i=-1    
    body_params.concat( strings.map {|s| i+=1;
                                         ["req#{i}_key",s]})
    url_params=[
      [:gsessionid, @gsessionid],
      [:VER, 8],
      [:SID, getSID() ],      
      [:RID, getRID()],
      [:AID, getAID()],
      [:zx, randomstring()],
      [:t, 1] 
    ]

    resp=@client.request(:post,CHANNEL_BASE_URI,
                               url_params,body_params)
    print resp.status ,' ', resp.reason, "\n" 
  end
end

class BackChannel < BrowserChannel
  def initialize(aid_holder, sticky_session, channel_SID,
                 debug_dev)
    @sid=channel_SID
    super(aid_holder, sticky_session,debug_dev)
  end
  def setAID(aid)
    @aidwrap.value=aid
  end
  
  
  def request
      url_params=[
      [:gsessionid, @gsessionid],
      [:VER, 8],
      [:RID, 'rpc'], 
      [:SID, @sid],
      [:CI, 1],
      [:AID, getAID()],
      [:TYPE, 'xmlhttp'],
      [:zx, randomstring()],
      [:t, 1] 
      ]
       connection=
          @client.request_async(:get, CHANNEL_BASE_URI,
                                url_params,nil,
                                'Connection'=>'keep-alive',
                                'Keep-Alive'=>'300' )
       message=connection.pop
       @stream=message.content
       #pp message.header
       print message.status," ",message.reason
       puts
  end
  def response
    if @stream.eof? then
       @stream.close # IO objects are leaked nonetheless!
                     # Possible bug in httpclient 2.1.5.2(?)
       return nil 
    end
    n=@stream.readline.to_i
    m=@stream.jread(n) if n>0
    m.each_line do |l|
      n=l[/^(\[|,)\[(\d+)/,2]
      self.setAID(n.to_i) if n
     
    end
    m
  end
end

$io_object_count=nil
$memleak_report_count=0
MAX_MEMLEAK_REPORTS=5

def count_objects(klass)
  ObjectSpace.each_object(klass).inject(0){|c,x| c+1}
end

def detect_and_report_memleak
 if $io_object_count.nil?
   $io_object_count=count_objects(IO)
 else
   new_count=count_objects(IO)
   if new_count > $io_object_count then
     STDERR << "Possible resource leak (#{new_count})\n" if $memleak_report_count < MAX_MEMLEAK_REPORTS
     $memleak_report_count +=1
   elsif new_count < $io_object_count then 
     STDERR << "Resources are being freed now (#{new_count})! There may be NO LEAK AFTER ALL!!\n" 
   end
   $io_object_count=new_count
 end
end


class Wfe
  def initialize(jsvars_filename, queue_filename, debug_dev=nil)

    @debug_dev=debug_dev 
    # @__fsd, @__session, @__client_flags
    read_wave_vars(jsvars_filename)
    @requests_input = SimpleFileQueue::Reader.new(QUEUE_FN)

    @sessionid=get_sessionid()
    @sticky=get_sticky_sessionid()

    
    RequestTemplateInterface.const_set(:PQID, predefined_query_id())
    @query_number=-1
    @r=0

  end
  # start the browser channel protocol
  def startup
    shared_aid_obj=BrowserChannel::AID.new
    @forward_channel=ForwardChannel.new(shared_aid_obj, @sticky, @debug_dev)
    @forward_channel.initChannel()
    sid=@forward_channel.getSID
    @back_channel=BackChannel.new(shared_aid_obj, @sticky, sid, @debug_dev)
  end
  
  # and run the main loop
  def run
    loop do
      @back_channel.request
      loop do
	send_queued_requests_if_any()
	m= @back_channel.response
        break if m.nil?
        puts "#{Time.now.strftime("%H:%M:%S")} #{m}"
      end
      detect_and_report_memleak if WARN_MEM_LEAK
    end
  end

  protected
   def get_sessionid
     @__session[:sessionData][:sessionid]
   end
   def get_sticky_sessionid
     @__session[:sessionData][:sticky_session]
   end
     

   def predefined_query_id
     @__fsd.requests.find {|r| r["r"] == "^d1"}["p"]["2"]
   end
  private
  def read_wave_vars(filename)
    jsvars=YAML.load_file JSVARS_FN
    @__fsd       = OpenStruct.new(jsvars.__fsd.value)
    @__session   = jsvars.__session
    @__client_flags = jsvars.__client_flags
  end

  def send_queued_requests_if_any
        templates = @requests_input.readall
	return nil if templates.empty?
	requests=templates.collect{|templ| message_from_template(templ)}
	@forward_channel.send_maps(*requests) 
  end
  
  module RequestTemplateInterface
   
   def message_from_template(  message_template)
     eval( '%Q{' + message_template +'}', binding)
   end
   protected
    attr_reader :__fsd, :__session, :__client_flags
    attr_reader :sessionid

    # next request message id
    def r
      rs=@r.to_s(16); @r+=1; rs
    end

    #Current query id
     def qid
	@sessionid + @query_number.to_s
     end

   #user ID a.k.a 'username'
   def un
     @__session[:userProfile][:username]
   end
	
     #Next (new) query id
     def nqid
	@query_number +=1
	qid
     end    
     
     # a random string with given length just in case we need one ...     
     def rndstr(l=8)
       set=('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
       (0...l).map{ set[rand(set.length)] }.join
     end 
  end
  include RequestTemplateInterface
end

=begin
  main program starts here
=end
DEBUG_DEV =  ( ARGV.include? "-d") ? STDERR : nil
WARN_MEM_LEAK =  ARGV.include? "-w"
wfe=Wfe.new(JSVARS_FN, QUEUE_FN, DEBUG_DEV)
wfe.startup
wfe.run

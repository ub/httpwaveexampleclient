#!/usr/bin/env ruby

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


def read_global_vars
   jsvars=YAML.load_file JSVARS_FN
    $__fsd       = OpenStruct.new(jsvars.__fsd.value)  
    $__session   = jsvars.__session
    $__client_flags = jsvars.__client_flags 
end

def count_objects(klass)
 ObjectSpace.each_object(klass).inject(0){|c,x| c+1}
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
      [:gsessionid, @gsessionid],
      [:VER, 8],
      [:RID, getRID()], 
      [:CVER, 4],
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
  
  # experimental version - ofset not keeped
  def send_strings_hack(ofs, *strings)
    count = strings.size
    
    body_params=[[:count, count],
                 [:ofs, ofs    ]
                ]
    i=-1    
    body_params.concat( strings.map {|s| i+=1; ["req#{i}_key",s]})
    url_params=[
      [:gsessionid, @gsessionid],
      [:VER, 8],
      [:SID, getSID() ],      
      [:RID, getRID()],
      [:AID, getAID()],
      [:zx, randomstring()],
      [:t, 1] 
    ]
    pp body_params
    resp=@client.request(:post,CHANNEL_BASE_URI,url_params,body_params)
    print resp.status ,' ', resp.reason, "\n" 
  end
end

class BackChannel < BrowserChannel
  def initialize(aid_holder, sticky_session, channelSID,debug_dev)
    @sid=channelSID   
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
       connection=@client.request_async(:get, CHANNEL_BASE_URI, url_params,nil,
                             'Connection'=>'keep-alive',
                             'Keep-Alive'=>'300' )  
       message=connection.pop
       puts connection.class.ancestors
       @stream=message.content
       #pp message.header
       print message.status," ",message.reason
       puts
  end
  def response
    if @stream.eof? then
       @stream.close # IO objects are leaked nonetheless! Possible bug in httpclient 2.1.5.2
       return nil 
    end
    n=@stream.readline.to_i
    m=@stream.jread(n) if n>0
    m.each_line do |l|
      n=l[/^(\[|,)\[(\d+)/,2]
      self.setAID(n.to_i) if n
      print "Next Array ID:",n,"\n"
    end
    m
  end
end

$io_object_count=nil
$memleak_report_count=0
MAX_MEMLEAK_REPORTS=5
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


  def randomString8
    set=('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    (0...8).map{ set[rand(set.length)] }.join
  end

def outgoing_msg2602
  $d1=$__fsd.requests.find {|r| r["r"] == "^d1"}
  a= $d1.to_json
end
def outgoing_msg2007(r)
  %{{"a":"#{$wsessionid}","r":"#{r}","t":2007,"p":{"1000":[0,0],"2":"#{randomString8()}"}}}
end  
def outgoing_msg2000(r)
  %{{"a":"#{$wsessionid}","r":"#{r}","t":2000,"p":{"1000":[0,0]}}}
end  
def outgoing_msg2012(r)
  %{{"a":"#{$wsessionid}","r":"#{r}","t":2012,"p":{"1000":[0,0]}}}
end  

=begin
  THE EXECUTION STARTS HERE 
=end



read_global_vars()

DEBUG_DEV =  ( ARGV.include? "-d") ? STDERR : nil
WARN_MEM_LEAK =  ARGV.include? "-w"
sticky    = $__session[:sessionData][:sticky_session]
$wsessionid = $__session[:sessionData][:sessionid]

shared_aid_obj=BrowserChannel::AID.new
forward=ForwardChannel.new(shared_aid_obj, sticky, DEBUG_DEV)
forward.initChannel()
sid=forward.getSID
back=BackChannel.new(shared_aid_obj, sticky, sid, DEBUG_DEV)

 forward.send_strings_hack(0,outgoing_msg2000(0))



loop do
back.request
loop do 
  m= back.response
  break if m.nil?
  puts "#{Time.now.strftime("%H:%M:%S")} #{m}"
end
  detect_and_report_memleak if WARN_MEM_LEAK
end
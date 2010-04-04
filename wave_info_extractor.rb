#
#
#  this code is made available under the MIT License (see MIT-LICENSE.txt)
#  Copyright (c) 2010 Yuri Baranov <baranovu+gh@gmail.com>
#



require 'json'

require 'js_subset_parser.rb'

class MainWavePageInfoExtractor
  SESS_REGEXP = /\bvar\s+__session\s*=\s*(?=\{)/
  REQ_REGEXP  = /__fsd.requests.push\(/
  RESP_REGEXP = /\bvar\s+json\s*=\s*\{"r":/     
protected    
  def attempt_parse_js(source)
    
    return JSON.parse(source)
  rescue JSON::JSONError =>error
    
    return nil
  end
    
  def json_extract(prefix, prepend, source , suffix="};",append="}")
    
    start = prepend + source.split(prefix,2)[1]
    parts=start.split(suffix)

      1.upto parts.size do |length|
	subparts=parts.slice(0,length)
	result=attempt_parse_js(subparts.join(suffix) +append)
	return result if result
      end
    return nil
  end  

 def initialize 
   @session_str=nil
   @fsd=(Struct.new(:requests,:responses)).new([],[])
 end
  
public
  def dispatch_line(line)
    case line
      when SESS_REGEXP
	@session_str=line
      when REQ_REGEXP  
	@fsd.requests << json_extract(REQ_REGEXP,"", line,"});")
      when RESP_REGEXP
	@fsd.responses << json_extract(RESP_REGEXP,'{"r":', line)
    end 
  end
  
def parse_global_js_vars
  if !@session_str
    STDERR << "__session javascript source not extracted!\n"
    return nil
  end
     parser=JsSubsetParser.new(@session_str)
     @jsvars=parser.parse_assignments
     @jsvars.__fsd=@fsd.dup
     @jsvars
  end
  
  def test_result
    rq=@jsvars.__fsd.requests  
    rs=@jsvars.__fsd.responses
    s=@jsvars.__session
    c=@jsvars.__client_flags 
    report=""
    report << "\nPredefined requests: "
    report <<
    if rq && ! rq.empty? && ! rq.include?(nil) then "OK (#{rq.size})" else "ERROR!" end
    report << "\nPredefined responses: "
    report <<
    if rs && ! rs.empty? && ! rs.include?(nil) then "OK (#{rs.size})" else "ERROR!" end
    report << "\nSession info: "
    report <<
    if s && s[:sessionData] && s[:sessionData][:sessionid] then "OK " else "ERROR!" end
    report << "\nClient flags: "
    report <<
    if c && c.has_value?('wave')then "OK" else "ERROR!" end
    report << "\n"
    return report , report["ERROR!"].nil?
  end
end


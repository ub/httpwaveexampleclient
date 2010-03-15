=begin
The MIT License

Copyright (c) 2010 Yuri Baranov <baranovu+gh@gmail.com>
Copyright (c) 2008 James Edward Gray II <james@grayproductions.net>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=end



require 'strscan'
require 'ostruct'
class MainWavePageInfoExtractor
end
class MainWavePageInfoExtractor::JsSubsetParser
  def initialize(source)
    @input=StringScanner.new(source)
  end
  
  # adapted from http://rubyquiz.com/quiz155.html
  AST = Struct.new(:value)
  ASGN = Struct.new(:var,:value) # var is a symbol, value a ruby object

  # parses list of javascript assignments - that's our source

  def parse_assignments 
    assignments=Hash.new
    while a=parse_assignment
      assignments[a.var]=a.value
      @input.skip(/;/) or return false
    end
    OpenStruct.new(assignments)
  ensure
      trim_space
      @input.eos? or raise "More data than necessary"
  end
      
  def parse_assignment
    trim_space
    parse_kw_var or return false 
    trim_space
    varname=parse_sym or return false # error Identifier expected
    @input.skip(/\s*=\s*/) or return false # TODO fail
    object=parse_value or return false # --"--
    ASGN.new(varname.value,object.value)
  end
    
    
  def parse_value
    parse_hash or
    parse_num  or
    parse_string or
    parse_bool or
    parse_null
  end

  def parse_key   
    parse_string or
    parse_sym    
  end

  def parse_sym
    @input.scan(/\w+/) and AST.new(@input.matched.to_sym)
  end

  def parse_string
    if @input.scan(/'/)
      v=@input.scan(/[^']*/)
      @input.skip(/'/) and AST.new(v) # error unterminated string
    else
      false
    end
  end

  def parse_bool
    @input.scan(/\b(false|true)\b/) and AST.new($matched =='true')
  end

  def parse_null
    @input.scan(/\bnull\b/) and AST.new(nil)
  end

  def parse_num
    @input.scan(/-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?\b/) and
	  AST.new(eval(@input.matched))
  end

  def parse_hash
    if @input.scan(/\{/)
	object     = Hash.new
	more_pairs = false
	while key=parse_key
	  @input.skip(/:/) or return false #error("Expecting object separator")
	  object[key.value] = parse_value.value
	  more_pairs = @input.skip(/,/) or break
	end
	return false if more_pairs # error("Missing object pair") 
	@input.skip(/\}/) or return false # error("Unclosed object")
	AST.new(object)
    else
      false
    end
  end

  def trim_space
  @input.skip(/\s+/)
  end

  def parse_kw_var
    @input.skip(/\bvar\b/)                  
  end
end #class

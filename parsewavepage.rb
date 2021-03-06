#!/usr/bin/env ruby
#
#
#  this code is made available under the MIT License (see MIT-LICENSE.txt)
#  Copyright (c) 2010 Yuri Baranov <baranovu+gh@gmail.com>
#



 require 'rubygems'

require 'pp'
require 'yaml'

require 'file_names.rb'
require 'wave_info_extractor.rb'


wpi_extractor= MainWavePageInfoExtractor.new

File.foreach( WAVE_FN ) do |line|
  wpi_extractor.dispatch_line(line.chop) 
end


jsvars=wpi_extractor.parse_global_js_vars
puts wpi_extractor.test_result[0]

File.open(JSVARS_FN, "w"){|f| YAML.dump(jsvars,f)} 
File.delete(JSVARS_FN) unless jsvars

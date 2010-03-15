#
#
#  this code is made available under the MIT License (see MIT-LICENSE.txt)
#  Copyright (c) 2010 Yuri Baranov <baranovu+gh@gmail.com>
#


# A quik and dirty IPC via the file
# each message is a single line terminated with \n
#  
# May not be 100% bulletproof, but good enough for
# non-critical code for interactive experiments.
#
# Also, easier to implement and understand than, say, Drb-based
# or HTTP-server based solution 
module SimpleFileQueue
  class Reader
    def initialize(filename)
      @rfn=filename
      @pos=0
    end
    def read
      return nil unless open()
      @fr.pos=@pos
      result=readline 
      @pos=@fr.pos if result #advance position on success
      return result 
    ensure
      close
    end
    #returns array of strings
    def readall
      return [] unless open()
       @fr.pos=@pos
      result= []
       while s=readline do
	 @pos=@fr.pos
         result << s
       end
       return result
    ensure
      close
    end
    
    #private
    def open
      @fr=File.new(@rfn,'r')
    rescue
      nil
    end
    
    def close
      @fr.close if @fr
      @fr=nil
    end
    
    def readline
      result=@fr.readline
      # if line is complete, return it without the terminating "\n"
      return result[-1,1]=="\n" ? result.chop! : nil
    rescue 
      nil
    end
    
  end
  
  class Writer
    def initialize(filename, new = true)
      @wfn=filename
      if new then
	 File.open(@wfn, "w"){}
      else
       reopen
       close
      end
    end
    def <<(string)
      reopen
      n=nil
      if @fw then
	 n=@fw.write(string)
	 @fw.write("\n")
	 @fw.flush
      end
      return n == string.bytesize
    ensure
      close
    end
    private
    def reopen     
      @fw=File.new(@wfn, "a")
    rescue 
      nil
    end
    def close
      @fw.close if @fw
      @fw=nil
    end
  end
end

#!/usr/bin/env ruby
#
#  wfereqsbuilder.rb - Interactive builder for wfe requests
#                  Offers user a menu to create request templates
#                  and appends requests to the 'wfereqs' file
#                  For talktowave.rb to read and send
#
#  this code is made available under the MIT License (see MIT-LICENSE.txt)
#  Copyright (c) 2010 Yuri Baranov <baranovu+gh@gmail.com>
#

require "rubygems"
require "highline/import"
require "pp"

#NOTICE: THIS UTILITY IS UNDER CONSTRUCTION as of 29-03-2010

=begin
 choose do |menu|
    menu.index=:none

    menu.prompt = "Please choose your favorite programming language?  "

    menu.choice(:ruby) { say("Good choice!") }
      menu.choices(:python, :perl) { say("Not from around here, are you?") }
  end

=end

pattern={"a"=>"\#{sessionid}", "t"=>2007, "w"=>[]}

=begin
ok=choose do |menu|
  menu.index  = :none
  menu.prompt = "Choose the property to change (top level)"
  pattern.each_pair do |key, default_value|
    menu.choice(key +" ["+default_value.inspect + "] ") {say(default_value.to_s); 42}

  end
  end
=end

def deepcopy(o)
  Marshal.load(Marshal.dump(o))
end

Marshal.

class Hash
  def interactive_edit(parent,key_in_parent,prompt="> ")
    #TODO: possibly refactor with the use of infinite while true/until false modifier 
    done=false
    choose do |menu|
      menu.index  = :none
      menu.prompt = "Choose the property to change or ':.' command #{prompt} "
      self.each_pair do |key, default_value|
        menu.choice(key +" ["+default_value.inspect + "] ") {
          object=default_value.clone rescue default_value
          object1,force_nil=object.interactive_edit(self,key)
          self[key]=object1 if object1 or force_nil


        }
      end
      menu.choice(":x - accept the result") {done=true}
      menu.choice(":q - cancel the edit")   {return nil, false}
    end until done
    return self
  end
end

class Integer
    def interactive_edit(parent,key_in_parent,prompt="> ")
      ask(key_in_parent.to_s + prompt,Integer) {|question| question.default=self.clone rescue self}
    end
end

class String
    def interactive_edit(parent,key_in_parent,prompt="> ")
      ask(key_in_parent.to_s + prompt,String) {|question| question.default=self.clone rescue self}
    end
end


# wfe requests'  have following kind of Arrays:
# 1. empty
# 2. of Strings
# 3. of Integers
# 4. of Hashes
#
class Array
  def interactive_edit(parent, key_in_parent, prompt="> ")
    self[0].interactive_edit_member_helper(self, parent, key_in_parent, prompt)
  end
end

class NilClass
  def interactive_edit_member_helper(array, parent_of_array, key, prompt)
     choose do |menu|
       menu.prompt = "Add an element of which class? #{prompt} "
       menu.choice(Integer) {array << 0}
       menu.choices(String, Hash) {|klass| array << klass.new }
       menu.choice("do not add anything")
       end
     return array, false
     end
  end

module StringAndHashInteractiveEditHelper
  def interactive_edit_member_helper(array, parent_of_array, key, prompt)
    done=false
    choose do |menu|
      menu.index  = :none
      menu.prompt = "Choose a command (:a/:d/:e)  #{prompt} "

      #TODO: we are here!
      menu.choice(":a - append new element") {}# append (duplicate) element (ask which if more than one  non-indentical)
      menu.choice(":d - delete last element"){}
      menu.choice(":e - edit element (choose an index)"){} # edit element (ask which if more than one)
      menu.choice(":x - accept changes"){}
      menu.choice(":q - cancel changes"){}



    end until done

  end
end

class String
  include StringAndHashInteractiveEditHelper
end
class Hash
  include StringAndHashInteractiveEditHelper
end


result= pattern.interactive_edit(nil,2007)
puts result
pp result
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
require "json"
require "pp"

require 'file_names.rb'
require "file_queue.rb"


#NOTICE: THIS UTILITY IS UNDER CONSTRUCTION as of 29-03-2010


def deepcopy(o)
  Marshal.load(Marshal.dump(o))
end



class Hash
  def interactive_edit(parent,key_in_parent,prompt="> ")
    #TODO: possibly refactor with the use of infinite while true/until false modifier
  
    working_copy=deepcopy(self)
    done=false
    choose do |menu|
      menu.index  = :none
      menu.prompt = "Choose the property to change or ':.' command #{prompt} "
      working_copy.each_pair do |key, default_value|
        menu.choice(key +" |"+default_value.to_json + "| ") {
          object=default_value.clone rescue default_value
          object1,force_nil=object.interactive_edit(working_copy,key)
          working_copy[key]=object1 if object1 or force_nil


        }
      end
      menu.choice(":n - add new key")       {new_key = ask( "Key? "){|question|
        question.responses[:not_valid]="This key is already present or is not valid!"
        question.validate=Proc.new{|answer| !(working_copy.include?(answer) or
                answer.empty? or
                answer.first == ?: )
          }
        }


        value =     NewHashValueHelper::create_interactively

        working_copy[new_key]=value
        }
      menu.choice(":d - delete key")  {key_to_delete = ask("Which key? "){|question|
        question.responses[:not_valid]="No such key!"
        question.validate=Proc.new {|answer| working_copy.include?(answer)}
        }
        working_copy.delete key_to_delete
      }

      menu.choice(":x - accept the result") {done=true}
      menu.choice(":q - cancel the edit")   {return nil, false}
    end until done
    return working_copy
  end
end

class Integer
    def interactive_edit(parent,key_in_parent,prompt="> ")
      ask(key_in_parent.to_s + prompt,Integer) {|question| question.default=self}
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
       menu.prompt = "Which class? #{prompt} "
       menu.choice(Integer) {array << 0}
       menu.choices(String, Hash) {|klass| array << klass.new }
       menu.choice("do not add anything")
       end
     return array, false
     end
end

module NewHashValueHelper
  def self.create_interactively(prompt =" >")
    choose do | menu |
      menu.prompt = "Which class? #{prompt} "
      menu.choice(Integer) {0}
      menu.choices(String, Hash, Array) {|klass|  klass.new }
      menu.choice("null (nil)") {nil}
    end
  end
end

module MemberInteractiveEditHelper
  def interactive_edit_member_helper(array, parent_of_array, key, prompt)
    working_copy=deepcopy(array)
    done=false
    choose do |menu|
      menu.index  = :none
      menu.header = working_copy.to_json
      menu.prompt = "Choose a command (:a/:d/:e)  #{prompt} "


      menu.choice(":a - append new element") {# append (duplicate) element (ask which if more than one  non-indentical)
        uniq=working_copy.uniq

        index=case uniq.size
        when 1 then 0
        else
          ask("Index of element to clone (0 - #{working_copy.size - 1}): ",Integer) {|question|
            question.in=0..(working_copy.size - 1)}
          end
        working_copy << deepcopy(working_copy[index])
        }  unless working_copy.empty?
      menu.choice(":d - delete last element"){working_copy.delete_at(-1)} unless working_copy.empty?
      menu.choice(":e - edit element (choose an index)"){ # edit element (ask which if more than one)
        index= working_copy.size == 1 ? 0 :
                ask("Index of element to edit (0 - #{working_copy.size - 1}): ",Integer) {|question|
                  question.in=0..(working_copy.size - 1)}
        result,force_nil=working_copy[index].interactive_edit(working_copy,index, ">> ")
        working_copy[index]=result if result or force_nil
        }unless working_copy.empty?
      menu.choice(":x - accept changes"){return working_copy,false}
      menu.choice(":q - cancel changes"){return nil,false}


      end until done

    end
  end

class Integer
  include MemberInteractiveEditHelper
end

class String
  include MemberInteractiveEditHelper
end
class Hash
  include MemberInteractiveEditHelper
end


=begin

result= pattern.interactive_edit(nil,2007)
puts result
pp result
=end
class WfeRequestsManager
  private
  def initialize
     @request_prototypes={}
     @output = SimpleFileQueue::Writer.new(QUEUE_FN)
  end

# return Hash where keys are message types, and values are arrays of prototypes
# of the given type
  def read_message_prototypes(filename)
    lines=File.open(filename,"r").lines
    request_prototypes=lines.map{|each| JSON.parse each}.compact
    request_prototypes.group_by{|each| each["t"].to_s}
  end
  def read_all(directory)
    Dir.foreach(directory) do |filename|
      full_name = File.expand_path(filename, directory)
      @request_prototypes.merge_groups!(read_message_prototypes(full_name)) if File.file? full_name
    end
  end
  attr_accessor :request_prototypes
  private :read_message_prototypes

  def choose_wfe_type

    rk=choose  do | menu |
      menu.index=:none
      menu.select_by=:name
      menu.extend(NumericalWordsMenuPatch)
      menu.answer_type=String
      menu.prompt="Select the message type you'd like to play with> "
      @request_prototypes.each_key {| key | menu.choice(key)  }
       menu.choice(":q - enough!") {puts("Bye!");exit(0);}
    end
    @request_prototypes[rk]
  end

  def choose_prototype
    array=choose_wfe_type
    return array.first if array.size == 1
    choose do |menu|
      menu.index=:number
      menu.prompt="Select the message prototype> "
      
      array.each {|obj| menu.choice(obj.to_json ){obj} }

    end
  end

  def work_with_prototype(wfe_message)
    loop do
    choose do |menu|
      menu.header=wfe_message.to_json
      menu.index=:letter
      menu.prompt="Select an action> "
      menu.choice("accept and send to queue") {@output << wfe_message.to_json ; return true}
      menu.choice("modify") {wfe_message=wfe_message.interactive_edit(nil,wfe_message['t'])}
      menu.choice("cancel") {return true}
      menu.choice("quit")   {return false}
    end
    end

  end

  def run
    go_on=true
    while go_on do
      wfe_message=choose_prototype
      go_on= work_with_prototype(wfe_message)
    end
  end

  public :run,:read_all
end


#Monkey patch for Highline Menu
module NumericalWordsMenuPatch
  def select( highline_context, selection, details = nil )
    # add in any hidden menu commands
    @items.concat(@hidden_items)

    # Find the selected action.


      l_index = "`"
      index = @items.map { "#{l_index.succ!}" }.index(selection)
     name, action = ( @items.find { |c| c.first == selection } or @items[index])


    # Run or return it.
    if not @nil_on_handled and not action.nil?
      @highline = highline_context
      if @shell
        action.call(name, details)
      else
        action.call(name)
      end
    elsif action.nil?
      name
    else
      nil
    end
  ensure
    # make sure the hidden items are removed, before we return
    @items.slice!(@items.size - @hidden_items.size, @hidden_items.size)
  end


end

class Hash
  # Merge two hashes having the structure like that of  the result of Enumberable#group_by method
  def merge_groups(other)
    result={}
    (self.keys | other.keys).each {|key| result[key]=Array(self[key]) | Array(other[key])}
    return result
  end
  def merge_groups!(other)
    right=other.dup
    self.each_pair {|key, array| array |= Array(right.delete(key)) }
    self.merge!(right)
  end
end
#see samples/rtj
#
#pp read_message_prototypes_j("samples/rtj")
#

manager=WfeRequestsManager.new
manager.read_all("wfe_prototypes")

manager.run

=begin

pattern={'1'=>[],'2'=>[0],'3'=>["word"]}
pattern.interactive_edit(nil,nil)
=end

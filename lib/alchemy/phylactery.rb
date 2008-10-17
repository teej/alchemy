require 'thread'
require 'json'

module AlchemyServer
  
  class Phylactery
    
    def initialize
      @shutdown_mutex = Mutex.new
      @lists = {}
      @list_init_mutexes = {}
      @stats = Hash.new(0)
    end
    
    def set(key, data)
      list = lists(key)
      return false unless list
      
      value = value_for_data(data)
      list.push(value)
      
      return true
    end
    
    
    def add(key, data)
      list = lists(key)
      return false unless list
      
      value = value_for_data(data)
      return false if list.include?(value)
      list.push(value)
      
      return true
    end
    
    ## Special.  Expects data to be a JSON array
    def replace(key, data)
      list = lists(key)
      return false unless list
      value = JSON.parse(data)
      return false unless value.is_a? Array
      list.replace(value)
      
      return true
    end
    
    alias :append :set
    
    def prepend(key, data)
      list = lists(key)
      return false unless list
      
      value = value_for_data(data)
      list.unshift(value)
      
      return true
    end
    
    ## CAS command not supported
    
    def get(key)
      list = lists(key).to_a
      return false if list.empty?
      return list.to_json
    end
    
    def gets(keys)
      all_lists = {}
      keys.each { |key| all_lists[key] = lists(key).to_a }
      return all_lists.to_json
    end
    
    def delete(key)
    	@lists.delete(key)
    end
    
    def flush_all
      @lists = {}
      @list_init_mutexes = {}
    end
    
    ##
    # Returns all active lists. 

    def lists(key=nil)
      return nil if @shutdown_mutex.locked?

      return @lists if key.nil?
      # First try to return the list named 'key' if it's available.
      return @lists[key] if @lists[key]
      
      @list_init_mutexes[key] ||= Mutex.new
      
      if @list_init_mutexes[key].locked?
        return nil
      else
        @list_init_mutexes[key].lock
        if @lists[key].nil?
          @lists[key] = []
        end
        @list_init_mutexes[key].unlock
      end

      return @lists[key]
    end

    ##
    # Returns statistic +stat_name+ for the Recipes.
    #
    # Valid statistics are:
    #
    #   [:get_misses]    Total number of get requests with empty responses
    #   [:get_hits]      Total number of get requests that returned data
    #   [:current_bytes] Current size in bytes of items in the lists
    #   [:current_size]  Current number of items across all lists
    #   [:total_items]   Total number of items stored in lists.

    def stats(stat_name)
      case stat_name
      when nil; @stats
      when :current_size; current_size
      else; @stats[stat_name]
      end
    end

    ##
    # Safely close all lists.

    def close
      @shutdown_mutex.lock
    end

    private

    def current_size #:nodoc:
      @lists.inject(0) { |m, (k,v)| m + v.length }
    end
    
    def value_for_data(data)
      # if the data is an integer, save it as such.  otherwise, save as a string
      (data.to_i.to_s == data) ? data.to_i : data
    end
    
  end
end

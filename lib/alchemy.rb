require 'memcached'
require 'json'

class Alchemy < Memcached
  ## SETTERS
  def set(key, value, timeout=0)
    check_return_code(
      Lib.memcached_set(@struct, key, value.to_s, timeout, FLAGS)
    )
  end
  
  def add(key, value, timeout=0)
    check_return_code(
      Lib.memcached_add(@struct, key, value.to_s, timeout, FLAGS)
    )
  end
  
  def replace(key, value, timeout=0)
    check_return_code(
      Lib.memcached_replace(@struct, key, value.to_s, timeout, FLAGS)
    )
  end
  
  ## GETTER
  def get(keys)#, marshal=true)
    if keys.is_a? Array
      # Multi get
      keys.map! { |key| key }
      hash = {}
      
      ret = Lib.memcached_mget(@struct, keys);
      check_return_code(ret)
      
      keys.size.times do 
        value, key, flags, ret = Lib.memcached_fetch_rvalue(@struct)
        break if ret == Lib::MEMCACHED_END
        check_return_code(ret)
        hash[key] = JSON.parse(value)
      end
      hash
    else
      # Single get
      value, flags, ret = Lib.memcached_get_rvalue(@struct, keys)
      #check_return_code(ret)
      unless value.empty?
        value = JSON.parse(value)
      else
        value = nil
      end
      value
    end    
  end
  
end
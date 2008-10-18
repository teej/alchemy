module UsesAlchemy
	
	def uses_alchemy(association_id, opts={})
		opts[:on]	||= "#{self.name.downcase}_id"
		opts[:name]	||= association_id
		opts[:store] ||= :id
		
		klass = association_id.to_s.singularize.camelize.constantize
		opts[:proc] ||= Proc.new { |list| list.map{ |aid| klass.find(aid) } }
		
		alchemy_namespace = "#{association_id}_#{opts[:on]}"
		alchemy_listname ="#{alchemy_namespace}_list_name"
		
		define_method(alchemy_listname) do
			"#{self.class}|#{id}|#{alchemy_namespace}"
		end
		
		define_method(opts[:name]) do |*reload|
			list = ALCHEMY.get(send(alchemy_listname)) if !reload.first
			
			if reload.first || list.nil?
			  refreshed_list = klass.find(:all, :select=>"#{opts[:store]}, #{opts[:on]}", :conditions=>["#{opts[:on]} = ?", self.id])
			  refreshed_list = refreshed_list.map(&opts[:store])
			  ALCHEMY.replace(send(alchemy_listname), refreshed_list.to_json)
			  list = refreshed_list
			end
			opts[:proc].call(list)
		end
	end
	
end
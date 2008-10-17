module ActiveRecord
	module Associations
		module ClassMethods
			def alchemized_by(association_id, opts={})
				
				opts[:with] ||= "#{association_id}_id"
				opts[:with] = opts[:with].to_a
				opts[:on] ||= :id
				
				opts[:with].each do |method|
					
					alchemy_namespace = "#{self.name.underscore.pluralize.downcase}_#{method}"
					alchemy_listname = "#{method}_list_name"
					
					define_method(alchemy_listname) do
						"#{association_id.to_s.camelize}|#{send(method)}|#{alchemy_namespace}"
					end
					
					define_method("alchemize_#{method}") do
						ALCHEMY.set(send(alchemy_listname), self.send(opts[:on]))
					end
					
				end
			end
		end
	end
end
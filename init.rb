['uses_alchemy', 'alchemized_by'].each do |req|
	require File.join(File.dirname(__FILE__), "lib/alchemy/#{req}")
end
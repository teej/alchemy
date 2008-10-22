Gem::Specification.new do |s|
  s.name     = "alchemy"
  s.version  = "1.1.1"
  s.date     = "2008-10-17"
  s.summary  = "A simple, light-weight list caching server"
  s.email    = "teej.murphy@gmail.com"
  s.homepage = "http://github.com/teej/alchemy"
  s.description = "Alchemy is fast, simple, and distributed list caching server intended to relieve load on relational databases,"
  s.has_rdoc = true
  s.authors  = ["TJ Murphy"]
  s.files    = ["License.txt", 
		"README.rdoc",
		"alchemy.gemspec",
		"init.rb",
		"bin/alchemy",
		"lib/alchemy.rb",
		"lib/alchemy/handler.rb",
    "lib/alchemy/phylactery.rb",
    "lib/alchemy/runner.rb",
    "lib/alchemy/server.rb",
    "lib/alchemy/alchemized_by.rb",
    "lib/alchemy/uses_alchemy.rb"]
  s.test_files = []
  s.executables = ["alchemy"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.extra_rdoc_files = ["README.rdoc"]
  s.add_dependency("json", ["> 1.0.0"])
  s.add_dependency("memcached", [">= 0.11"])
  s.add_dependency("eventmachine", [">= 0.12.2"])
end

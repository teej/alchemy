require 'rbconfig'
require 'ftools'
include Config
bindir = CONFIG["bindir"]
install_dir = File.join(bindir, "alchemy")
link_dir = File.join("/usr", "bin", "alchemy")

File::unlink(link_dir)
File::delete(install_dir)

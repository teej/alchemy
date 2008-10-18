require 'rbconfig'
require 'ftools'
include Config
bindir = CONFIG["bindir"]
install_dir = File.join(bindir, "alchemy")
link_dir = File.join("/usr", "bin", "alchemy")

File::install(File.join("bin", "alchemy"), install_dir, 0755, true)
File::symlink(install_dir, link_dir)

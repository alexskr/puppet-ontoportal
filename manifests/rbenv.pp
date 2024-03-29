class ontoportal::rbenv(
  String $ruby_version     = $title,
  String $rubygems_version = '3.4.18',
  String $bundler_version  = '2.4',
  Boolean $global          = true
) {
  class { 'rbenv': }
  -> rbenv::plugin { ['rbenv/ruby-build']: latest => true }
  -> rbenv::build { $ruby_version:
#    rubygems_version => $rubygems_version,
    bundler_version => $bundler_version,
    global          => $global,
  }
  # for unknown reason setting rubygems_version in the rbenv::build fails so we have a work around:
  -> exec { "upgrade rubygems to version ${rubygems_version}":
    command => "/usr/local/rbenv/shims/gem update --system ${rubygems_version}",
    unless  => "/usr/local/rbenv/shims/gem --version | grep -q ${rubygems_version}",
  }
}

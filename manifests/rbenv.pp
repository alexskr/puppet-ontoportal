define ontoportal::rbenv(
  String $ruby_version     = $title,
  String $rubygems_version = '3.5.20',
  String $bundler_version  = '2.5.20',
  Boolean $global          = true
) {

  #ruby can take a while to compile
  Exec { timeout => 1800 }

  class{ 'rbenv':
    env => ["TMPDIR=/var/tmp"], #ubuntu mounts /tmp with noexec by defualt which breaks ruby build
  }

  if !defined(Rbenv::Plugin['rbenv/ruby-build']) {
    rbenv::plugin { ['rbenv/ruby-build']: latest => true }
  }
  rbenv::build { $ruby_version:
    rubygems_version => $rubygems_version,
    bundler_version  => $bundler_version,
    global           => $global,
  }
}

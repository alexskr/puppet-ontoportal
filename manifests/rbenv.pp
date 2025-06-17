define ontoportal::rbenv (
  String $ruby_version     = $title,
  String $rubygems_version = '3.5.20',
  String $bundler_version  = '2.5.20',
  Boolean $global          = true
) {
  # ruby can take a while to compile
  Exec { timeout => 1800 }

  class { 'rbenv':
    env => [
      'TMPDIR=/var/tmp',  # in case if /tmp is mounted with noexec which will break ruby build
      "MAKE_OPTS=-j${facts['processors']['count']}" # use all available cores to speed up builds
    ],
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

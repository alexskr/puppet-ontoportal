class ontoportal::rbenv(
  String $ruby_version     = $title,
  String $rubygems_version = '3.2.3',
  String $bundler_version  = '2.4',
  Boolean $global          = true
) {
  class { 'rbenv': }
  rbenv::plugin { ['rbenv/rbenv-vars', 'rbenv/ruby-build']: latest => true }
  rbenv::build { $ruby_version:
    rubygems_version => $rubygems_version,
    bundler_version  => $bundler_version,
    global           => $global,
  }
}

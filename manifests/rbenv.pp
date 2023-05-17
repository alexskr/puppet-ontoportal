class ontoportal::rbenv(
  String $ruby_version    = $title,
  String $bundler_version = '2.4',
  Boolean $global         = true
) {
  class { 'rbenv': }
  -> rbenv::plugin { ['rbenv/rbenv-vars', 'rbenv/ruby-build']: }
  -> rbenv::build { $ruby_version: global => $global }
  -> rbenv::gem { "bundler-v${bundler_version}-for-${ruby_version}":
    gem          => 'bundler',
    version      => $bundler_version,
    skip_docs    => true,
    ruby_version => $ruby_version,
  }
}

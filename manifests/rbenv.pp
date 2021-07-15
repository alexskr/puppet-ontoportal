class ontoportal::rbenv(
    String $ruby_version = $title,
    Boolean $global      = true
  ){
  class { '::rbenv': }
  -> rbenv::plugin { [ 'rbenv/rbenv-vars', 'rbenv/ruby-build' ]: }
  -> rbenv::build { $ruby_version: global => $global }
  -> rbenv::gem { "bundler-v2_0-for-${ruby_version}":
      gem          => 'bundler',
      version      => '~>2.0',
      skip_docs    => true,
      ruby_version => $ruby_version,
  }
}

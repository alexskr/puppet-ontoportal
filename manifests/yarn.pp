class ontoportal::yarn (
  String $nodejs_version = '20',
){

  class { 'nodejs':
    repo_version => $nodejs_version,  # Adjust version as needed
  }

  exec { 'enable_corepack':
    command => 'corepack enable',
    path    => ['/usr/bin', '/usr/local/bin'],
    unless  => 'which yarn',
    require => Package['nodejs'],
  }

  exec { 'install_yarn':
    command => 'corepack prepare yarn@stable --activate',
    path    => ['/usr/bin', '/usr/local/bin'],
    unless  => 'which yarn',
    require => Exec['enable_corepack'],
  }
}

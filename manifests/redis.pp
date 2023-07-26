#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis (
  Boolean $optimize_kernel      = true,
  Boolean $manage_repo          = true,
  Optional[String] $redis_version = undef,
) {
  case $facts['os']['family'] {
    'RedHat': {
      contain ontoportal::redis::install_redhat
    }
    'Debian': {
      contain redis
      #  contain ontoportal::redis::install_debian
    }
    default: {
      fail('Unsupported OS')
    }
  }

  # https://redis.io/topics/admin
  if  $optimize_kernel {
    include redis::administration
    kernel_parameter { 'transparent_hugepage':
      ensure => present,
      value  => 'never',
    }
  }
}

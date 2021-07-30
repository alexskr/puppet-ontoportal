# base redis wrapper class for redis instances.

class ontoportal::redis_base (
  Boolean $optimize_kernel = true,
  Boolean $manage_repo     = true,
) {
  unless $manage_repo {
    require epel
  }
  class { 'redis::globals':
    scl => 'rh-redis5',
  }
  class { 'redis':
    default_install => false,
    service_enable  => false,
    service_ensure  => 'stopped',
    manage_repo     => $manage_repo,
    #service_manage => false,
  }

  #https://redis.io/topics/admin
  if  $optimize_kernel {
    include redis::administration
    # NOTE: kernel_paramenter requires reboot
    kernel_parameter { 'transparent_hugepage':
      ensure => present,
      value  => 'never',
    }
  }
}

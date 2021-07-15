#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis_base(
  Boolean $optimize_kernel = true,
  Boolean $manage_repo     = true,
  ){

  unless $manage_repo {
    require epel
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
  #   sysctl { 'vm.overcommit_memory': value => '1' }
  #   kernel_parameter { 'transparent_hugepage':
  #     ensure => present,
  #     value  => 'never',
  #   }
  }
}

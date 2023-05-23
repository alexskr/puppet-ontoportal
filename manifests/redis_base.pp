#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis_base(
  Boolean $optimize_kernel      = true,
  Boolean $manage_repo          = true,
  String $redis_version         = 'rh-redis6',
){

  class { 'redis::globals':
    scl => $redis_version,
  }
  alternative_entry { "/opt/rh/${redis_version}/root/usr/bin/redis-cli":
    ensure   => present,
    altlink  => '/usr/bin/redis-cli',
    altname  => 'redis-cli',
    priority => 1,
    require  => Class['redis'],
  }
  class { 'redis':
    default_install => false,
    service_enable  => false,
    service_ensure  => 'stopped',
    log_dir         => '/var/log/redis',
    manage_repo     => $manage_repo,
    #service_manage => false,
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

#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis::persistent(
  Optional[String] $maxmemory = undef,
  Stdlib::Port $port          = 6379,
  Boolean $manage_firewall    = true,
  Boolean $optimize_kernel    = true,
  Boolean $manage_repo        = false,
  Boolean $protected_mode     = false,
  Boolean $manage_newrelic    = true,
  Stdlib::Absolutepath $workdir  = '/srv/ontoportal/data/redis_persistent',
  $fwsrc = lookup("ontologies_api_nodes_${facts['ncbo_environment']}", undef, undef, [])
    + lookup('ips.vpn', undef, undef, [])
    + lookup("mgrep_${facts['ncbo_environment']}", undef, undef, [])
  ){
  include ontoportal::redis
  $redis_role = 'persistent'

  if $manage_firewall {
    firewall_multi { "33 allow redis on port ${port}":
      source => $fwsrc,
      dport  => $port,
      proto  => tcp,
      action => accept,
    }
  }

  redis::instance { $redis_role:
    port                  => 6379,
    workdir               => $workdir,
    protected_mode        => $protected_mode,
    timeout               => 3600,
    tcp_keepalive         => 600,
    service_enable        => true,
    service_ensure        => 'running',
    # persistent redis instance can take a while to start
    service_timeout_start => 600,
    service_timeout_stop  => 600,
    bind                  => [],
    unixsocket            => '',
  }

  if $manage_newrelic {
    class { 'profile::ncbo::newrelic::redis':
      redis_role => "redis_${redis_role}",
      port       => $port,
    }
  }

  if $facts['os']['family'] == 'RedHat' {
    selinux::fcontext {'set-redis-data-context':
      seltype => 'redis_var_lib_t',
      pathspec => "${workdir}(/.*)?",
    }
    selinux::exec_restorecon {"${workdir}":
      unless => "/bin/ls -adZ ${workdir}/* | /bin/grep -v redis_var_lib_t",
    }
  }
}

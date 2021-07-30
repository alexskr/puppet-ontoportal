#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis_persistent (
  Optional[String] $maxmemory = undef,
  Stdlib::Port $port          = 6379,
  Boolean $manage_firewall    = true,
  Boolean $optimize_kernel    = true,
  Boolean $manage_repo        = false,
  Boolean $protected_mode     = false,
  Boolean $manage_newrelic    = true,
  Stdlib::Absolutepath $workdir = '/srv/ontoportal/data/redis_persistent',
  $fwsrc = undef,
) {
  $redis_role = 'persistent'

  include ontoportal::redis_base

  if $manage_firewall {
    firewall_multi { "33 allow redis on port ${port}":
      source => $fwsrc,
      dport  => $port,
      proto  => tcp,
      action => accept,
    }
  }

  redis::instance { $redis_role:
    port           => 6379,
    workdir        => $workdir,
    protected_mode => $protected_mode,
    timeout        => 3600,
    tcp_keepalive  => 600,
    service_enable => true,
    service_ensure => 'running',
    bind           => [],
    unixsocket     => '',
  }

  if $manage_newrelic {
    class { 'ontoportal::newrelic::redis':
      redis_role => "redis_${redis_role}",
      port       => $port,
    }
  }
}

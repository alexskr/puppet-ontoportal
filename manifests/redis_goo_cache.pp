#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis_goo_cache (
  Optional[String] $maxmemory = undef,
  Stdlib::Port $port          = 6381,
  Boolean $manage_firewall    = true,
  Boolean $manage_newrelic    = true,
  $fwsrc = undef,
) {
  $redis_role = 'goo_cache'

  require ontoportal::redis_base

  if $maxmemory {
    $_maxmemory = $maxmemory
  } else {
    # allocate 80% of RAM to Redis for systems less than 32G
    if $facts['memory']['system']['total_bytes'] < 32*1024*1024*1024 {
      $_maxmemory = $facts['memory']['system']['total_bytes'] * 7 / 10 # 70%
    } else {
      $_maxmemory = $facts['memory']['system']['total_bytes'] * 8 / 10 # 80%
    }
  }

  redis::instance { $redis_role:
    port             => $port,
    save_db_to_disk  => false,
    protected_mode   => false,
    timeout          => 3600,
    tcp_keepalive    => 600,
    service_enable   => true,
    service_ensure   => 'running',
    maxmemory_policy => 'allkeys-lru',
    maxmemory        => $_maxmemory,
    bind             => [],
    unixsocket       => '',
    # bind           => $facts['networking']['ip'],
    #service_manage  => true,
  }

  if $manage_firewall {
    firewall_multi { "33 allow redis on port ${port}":
      source => $fwsrc,
      dport  => $port,
      proto  => tcp,
      action => accept,
    }
  }

  if $manage_newrelic {
    class { 'ontoportal::newrelic::redis':
      redis_role => "redis_${redis_role}",
      port       => $port,
    }
  }
}

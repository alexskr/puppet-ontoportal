#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis(
  Optional[String] $maxmemory = undef,
  ){

  require epel
  include disable_transparent_hugepage

  if $maxmemory {
    $_maxmemory = $maxmemory
  } else {
    $_maxmemory = "$facts['memory']['system']['total_bytes'] * 2/3"
  }

  class { 'redis':
    protected_mode => 'no',
    maxmemory      => $_maxmemory,
    bind           => $facts['networking']['ip'],
  #service_manage => true,
  }
}

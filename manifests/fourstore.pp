class ontoportal::fourstore (
  Stdlib::Port       $port = 8080,
  Boolean $manage_firewall = true,
  $fwsrc                   = undef,
) {
  class { 'fourstore':
    port     => $port,
    data_dir => '/srv/4store/data',
  }
  if manage_firewall {
    firewall_multi { "34 allow 4store on port ${port}":
      source => $fwsrc,
      dport  => $port,
      proto  => tcp,
      action => accept,
    }
  }
}

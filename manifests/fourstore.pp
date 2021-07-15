class ontoportal::fourstore (
  Stdlib::Port $port = 8080,
  $fwsrc = lookup("ontologies_api_nodes_${facts['ncbo_environment']}", undef, undef, []) + lookup('ips.vpn', undef, undef, []),
){

  class { 'fourstore':
    port     => $port,
    data_dir => '/srv/4store/data',
  }

  firewall_multi { "34 allow 4store on port ${port}":
    source => $fwsrc,
    dport  => $port,
    proto  => tcp,
    action => accept,
  }
}


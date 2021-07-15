class ontoportal::bioportal_web_ui_memcached (
  $max_memory = undef,
  $ui_nodes   = lookup("bioportal_web_ui_nodes_${facts['ncbo_environment']}", undef, undef, ['127.0.0.1']),
) {

  if $max_memory {
    $_max_memory = $max_memory
  } else {
    $_max_memory = '85%'
  }

  class { 'memcached':
    max_memory    => $_max_memory,
    max_item_size => '5M',
    listen        => '0.0.0.0',
  }

  firewall_multi { '32 Allow inbound memcached':
    source => $ui_nodes,
    dport  => 11211,
    proto  => tcp,
    action => accept,
  }
}

class ontoportal::bioportal_web_ui_db (
  $db_password = '*E7451323526B8DB91197DB7FFA11A2B75DD74005',
  $ui_nodes = lookup("bioportal_web_ui_nodes_${facts['ncbo_environment']}", undef, undef, ['127.0.0.1']),
  ) {

  # FIXME profile::mysql is not available
  class { 'profile::mysql':
    bind_address            =>  '0.0.0.0',
    key_buffer_size         => '64M',
    innodb_buffer_pool_size => '64M',
    enable_utf8             => true,
  }

  mysql::db { "bioportal_web_ui_${ncbo_environment}":
    user     => 'bioportal_web_ui',
    password => $db_password,
    host     => '%', # should be restricted
    grant    => ['ALL'],
  }

  firewall_multi { '32 allow inbound mysql from UI systems':
    source => $ui_nodes,
    dport  => 3306,
    proto  => tcp,
    action => accept,
  }
}

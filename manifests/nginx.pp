#
# Class: ontoportal::nginx
#
# Description: wrapper class for managing common things for nginx
#
class ontoportal::nginx (
  Integer $logrotate_nginx     = 180,
  Boolean $enable_nginx_status = false,
  Boolean $manage_nginx_repo   = true,
  Boolean $manage_firewall     = true,
  Boolean $manage_logrotate    = true,
  Integer $logrotate_days      = 180,
) {
  if $manage_firewall {
    firewall_multi { "34 allow inbound on port ${port}":
      dport => [$port, $ssl_port],
      proto => tcp,
      jump  => accept,
    }
  }

  ensure_packages(['ssl-cert']) # needed for snakeoil ssl cert

  class { 'nginx':
    manage_repo              => $manage_nginx_repo,
    passenger_package_ensure => 'absent',
    client_max_body_size     => '512M',
    http_tcp_nopush          => 'on',
    gzip_proxied             => 'any',
    gzip_types               => 'text/plain text/css application/x-javascript text/xml application/xml application/xml+rss application/json text/javascript',
    server_purge             => true,
    confd_purge              => true,
    require                  => Package['ssl-cert'],
  }

  # Global Nginx Status Page
  if $enable_nginx_status {
    nginx::resource::server { 'localhost':
      ensure      => present,
      listen_port => 80,
      server_name => ['localhost'],
    }

    nginx::resource::location { '/nginx_status':
      ensure         => present,
      server         => 'localhost',
      ssl            => false,
      stub_status    => true,
      location_allow => ['127.0.0.1'],
      location_deny  => ['all'],
    }
  }

  if $manage_logrotate {
    class { 'ontoportal::nginx::logrotate':
      logrotate_days => $logrotate_days,
    }
  }
}

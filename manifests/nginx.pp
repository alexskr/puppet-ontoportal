#
# Class: ncbo::ontologies_api
#
# Description: This class manages common thing for ncbo bioportal core
# nginx - unicorn https://github.com/defunkt/unicorn/blob/master/examples/nginx.conf
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class ontoportal::nginx (

  Enum['staging', 'production', 'appliance', 'development'] $environment = 'staging',
  Integer $logrotate_nginx     = 180,
  Stdlib::Host $domain         = 'data.demo.ontoportal.org',
  Boolean $enable_letsencrypt  = false,
  Stdlib::Port $port           = 80,
  Stdlib::Port $ssl_port       = 443,
  Boolean $enable_nginx_status = false,
  Boolean $manage_nginx_repo   = true,
  Boolean $manage_firewall     = true,
  Boolean $manage_logrotate    = true,
  Integer $logrotate_days      = 180,
) inherits ontoportal::params {

  if $manage_firewall {
    firewall_multi { "34 allow inbound on port ${port}":
      dport  => [$port, $ssl_port],
      proto  => tcp,
      jump => accept,
    }
  }

  class { 'nginx':
    manage_repo              => $manage_nginx_repo,
    passenger_package_ensure => false,
    client_max_body_size     => '1G',
    http_tcp_nopush          => 'on',
    gzip_proxied             => 'any',
    gzip_types               => 'text/plain text/css application/x-javascript text/xml application/xml application/xml+rss application/json text/javascript',
    server_purge             => true,
    confd_purge              => true,
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

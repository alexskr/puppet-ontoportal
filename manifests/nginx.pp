#
# Class: ontoportal::nginx
#
# Description: Wrapper class for managing common NGINX config, including:
# - Global SSL + gzip tuning
# - Optional firewall rules
# - Optional logrotate
# - Optional NGINX status page
# - Optional canonical domain redirection or non-canonical blocking
#
class ontoportal::nginx (
  Stdlib::Port $port                      = 80,
  Stdlib::Port $port_https                = 443,
  Boolean $enable_status                  = false,
  Boolean $manage_repo                    = true,
  Boolean $manage_firewall                = false,
  Boolean $manage_logrotate               = true,
  Integer $logrotate_days                 = 180,
  Boolean $block_noncanonical_domains     = false,
  Array[Stdlib::Host] $status_allow_hosts = ['127.0.0.1'],
  Optional[Stdlib::Host] $canonical_redirect_domain = undef,
) {

  if $manage_firewall {
    firewall_multi { "34 allow inbound on ports ${port} and ${ssl_port}":
      dport => [$port, $ssl_port],
      proto => tcp,
      jump  => accept,
    }
  }

  stdlib::ensure_packages(['ssl-cert']) # Needed for snakeoil SSL cert

  class { 'nginx':
    manage_repo              => $manage_repo,
    passenger_package_ensure => 'absent',
    client_max_body_size     => '512M',
    http_tcp_nopush          => 'on',
    gzip_proxied             => 'any',
    gzip_types               => 'text/plain text/css application/x-javascript text/xml application/xml application/xml+rss application/json text/javascript',
    server_purge             => true,
    confd_purge              => true,
    require                  => Package['ssl-cert'],
  }

  # Global NGINX Status Page (if enabled)
  if $enable_status {
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
      location_allow => $status_allow_hosts,
      location_deny  => ['all'],
    }
  }

  # Canonical redirect or domain blocker (default server)
  if $canonical_redirect_domain and $block_noncanonical_domains {
    fail('Cannot enable both canonical redirection and non-canonical blocking. Choose one.')
  }

  if $canonical_redirect_domain {
    nginx::resource::server { 'canonical_redirect':
      listen_port    => $port,
      ssl_port       => $port_https,
      listen_options => 'default_server',
      server_name    => ['_'],
      index_files    => [],
      ssl            => true,
      ssl_cert       => '/etc/ssl/certs/ssl-cert-snakeoil.pem',
      ssl_key        => '/etc/ssl/private/ssl-cert-snakeoil.key',
      locations      => {
        '/' => {
          return => "301 https://${canonical_redirect_domain}\$request_uri",
        },
      },
    }
  }

  if $block_noncanonical_domains {
    nginx::resource::server { 'block_noncanonical':
      listen_port    => $port,
      ssl_port       => $port_https,
      listen_options => 'default_server',
      server_name    => ['_'],
      index_files    => [],
      ssl            => true,
      ssl_cert       => '/etc/ssl/certs/ssl-cert-snakeoil.pem',
      ssl_key        => '/etc/ssl/private/ssl-cert-snakeoil.key',
      location_deny  => ['all'],
    }
  }

  # Logrotate support
  if $manage_logrotate {
    class { 'ontoportal::nginx::logrotate':
      logrotate_days => $logrotate_days,
    }
  }
}


#
# Class: ontoportal::nginx
#
# Manages common NGINX configuration for OntoPortal.
#
# Parameters:
#
# [*port*]                      - The HTTP port to listen on (default: 80)
# [*port_https*]                - The HTTPS port to listen on (default: 443)
# [*enable_status*]             - Whether to enable the NGINX status page (default: false)
# [*manage_repo*]               - Whether to manage the NGINX package repository (default: true)
# [*manage_firewall*]           - Whether to manage firewall rules for NGINX (default: false)
# [*manage_logrotate*]          - Whether to manage logrotate for NGINX logs (default: true)
# [*logrotate_days*]            - Number of days to keep rotated logs (default: 180)
# [*block_noncanonical_domains*] - Whether to block non-canonical domains (default: false)
# [*status_allow_hosts*]        - Hosts allowed to access the status page (default: ['127.0.0.1'])
# [*canonical_redirect_domain*] - Domain to redirect to if canonical redirection is enabled (default: undef)
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
    firewall_multi { "34 allow inbound on ports ${port} and ${port_https}":
      dport => [$port, $port_https],
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
    gzip                     => 'on',
    gzip_min_length          => 512,
    gzip_proxied             => 'any',
    gzip_vary                => 'on',
    gzip_types               => [
      'text/plain',
      'text/css',
      'text/javascript',
      'application/javascript',
      'application/json',
      'application/xml',
      'application/x-javascript',
    ],
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

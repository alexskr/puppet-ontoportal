class ontoportal::nginx::proxy_api (
  Stdlib::Host $domain,
  Boolean $catch_all               = true, #must be disabled for canonical redirect or block all non-canonical domains
  Integer $logrotate_nginx         = 180,
  Optional[Array[String]] $slices  = [], #used as SAN for letsencrypt
  Optional[Stdlib::Absolutepath] $ssl_key  = undef,
  Optional[Stdlib::Absolutepath] $ssl_cert = undef,
  Boolean $manage_letsencrypt      = false,
  Boolean $enable_https            = true,
  Boolean $enable_https_redirect   = $enable_https,
  Stdlib::Port $port               = 80,
  Stdlib::Port $port_https         = 8443,
  Boolean $manage_firewall         = false,
  Enum['webroot', 'nginx'] $letsencrypt_plugin = 'nginx',
  Optional[Array[Stdlib::Absolutepath]] $letsencrypt_webroot_paths = ['/var/lib/letsencrypt/webroot'],
) {
  include ontoportal::nginx

  if $manage_firewall {
    firewall_multi { "34 allow inbound API on port ${port} and ${port_https}":
      dport => [$port, $port_https],
      proto => tcp,
      jump  => accept,
    }
  }

  $slices_fqdn = $slices.map |$item| { "${item}.${domain}" }

  # Configure ACME challenge location if using webroot plugin
  if $letsencrypt_plugin == 'webroot' {
    nginx::resource::location { 'letsencrypt-acme-challenge-api':
      ensure              => present,
      server              => 'ontologies_api',
      ssl                 => false,  # HTTP only
      location            => '^~ /.well-known/acme-challenge/',
      www_root            => $letsencrypt_webroot_paths[0],
      index_files         => [],
      location_cfg_append => {
        'default_type' => 'text/plain',
      },
    }
  }

  if $enable_https and $manage_letsencrypt {
    ontoportal::nginx::letsencrypt { $domain:
      domain        => $domain,
      san           => $slices_fqdn,
      plugin        => $letsencrypt_plugin,
      webroot_paths => $letsencrypt_webroot_paths,
    }
  }

  $_ssl_cert = ontoportal::tls_path($domain, 'cert', $ssl_cert)
  $_ssl_key  = ontoportal::tls_path($domain, 'key',  $ssl_key)

  $_enable_https_redirect = $enable_https and $enable_https_redirect

  $raw_append = @(NGINX_RAW_APPEND)
    if ($request_method !~ ^(GET|HEAD|PUT|PATCH|POST|DELETE|OPTIONS)$ ){
      return 405;
    }
  | NGINX_RAW_APPEND

  nginx::resource::server { 'ontologies_api':
    ensure           => present,
    server_name      => [$domain] + $slices_fqdn,
    listen_port      => $port,
    ssl_port         => $port_https,
    listen_options   => bool2str($catch_all, 'default_server', ''),
    proxy            => 'http://ontologies_api',
    index_files      => [],
    ssl              => $enable_https,
    ssl_redirect     => $_enable_https_redirect,
    ssl_cert         => $_ssl_cert,
    ssl_key          => $_ssl_key,
    proxy_set_header => ['X-Forwarded-For $proxy_add_x_forwarded_for', 'Host $http_host', 'X-Real-IP $remote_addr'],
  }
}

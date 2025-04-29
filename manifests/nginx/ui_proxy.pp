class ontoportal::nginx::ui_proxy (
  String $domain                   = 'demo.ontoportal.org',
  Boolean $canonical_redirect      = false,
  Boolean $enable_nginx_status     = true,
  Boolean $catch_all               = true,
  Integer $logrotate_nginx         = 180,
  Stdlib::Absolutepath $app_dir    = "/opt/bioportal_web_ui",
  Optional[Array[String]] $slices = [], #used as SAN for letsencrypt
  Stdlib::Absolutepath $ssl_key    = "/etc/letsencrypt/live/${domain}/privkey.pem",
  Stdlib::Absolutepath $ssl_fullchain = "/etc/letsencrypt/live/${domain}/fullchain.pem",
  Boolean $manage_letsencrypt      = false,
  Boolean $enable_https            = true,
  Boolean $enable_https_redirect   = true,
  Stdlib::Port $port               = 80,
  Boolean $manage_nginx_repo       = false,
  Boolean $manage_firewall         = false,
) {
  include ontoportal::nginx

  if $manage_firewall {
    include ontoportal::firewall::http
  }

  $slices_fqdn = $slices.map |$item| { "${item}.${domain}" }

  $canonical_redirect_hosts = [$domain] + $slices_fqdn

  if $enable_https and $manage_letsencrypt {
    ontoportal::letsencrypt { $domain:
      cron_success_command => '/bin/systemctl reload nginx.service',
      domain               => $domain,
      san                  => $slices_fqdn,
    }
  }

  if $manage_letsencrypt {
    # enable HTTPS if letsencrypt cert is generated
    # FIXME This method requires two puppet agent runs; first to request Letsencrypt certs
    # and second run to update cert paths.  Refactor is needed
    $enable_ssl = $domain in $facts['letsencrypt_directory']  # check whether letsencrypt cert is in place
    $_ssl_cert  = $ssl_fullchain #use full chain
    $_ssl_key   = $ssl_key
  } else {
    $enable_ssl = $enable_https
    # set to a self-signed cert so that nginx doesn't fall over before we get our cert
    $_ssl_cert  = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
    $_ssl_key   = '/etc/ssl/private/ssl-cert-snakeoil.key'
  }

  $_enable_https_redirect = $enable_ssl and $enable_https_redirect

  if $canonical_redirect {
    $_catch_all = undef
  } elsif $catch_all {
    $_catch_all = 'default_server'
  } else {
    $_catch_all = undef
  }

  if $canonical_redirect {
    nginx::resource::server { 'canonical_redirect':
      listen_port => $port,
      listen_options => 'default_server',
      server_name => ['_'],
      ssl         => $enable_ssl,
      ssl_cert     => $_ssl_cert,
      ssl_key      => $_ssl_key,
      raw_append => "return 301 https://${domain}\$request_uri;",
    }
  }

  # static files / assets file are served by nginx
  nginx::resource::location { '^~ /assets/':
    ensure      => present,
    ssl         => $enable_ssl,
    ssl_only    => $_enable_https_redirect,
    www_root    => "${app_dir}/current/public",
    gzip_static => 'on',
    expires     => '1y',
    server      => 'ontoportal_web_ui',
    add_header  => {
      'Cache-Control' => 'public',
    }, #response can be cached within proxies rails defaults to private
  }

  # Define the upstream Puma socket
  nginx::resource::upstream { 'puma-bioportal_web_ui':
    members => {
      'ui' => {
        server       => "unix:/run/puma-ui/puma.sock",
        fail_timeout => '0s',
      },
    },
  }

  $raw_append = @(NGINX_RAW_APPEND)
    location @503 {
      error_page 405 = /system/maintenance.html;
      if (-f $document_root/system/maintenance.html) {
        rewrite ^(.*)$ /system/maintenance.html break;
      }
      rewrite ^(.*)$ /503.html break;
    }

    if ($request_method !~ ^(GET|HEAD|PUT|PATCH|POST|DELETE|OPTIONS)$ ){
      return 405;
    }

    if (-f $document_root/system/maintenance.html) {
      return 503;
    }
  | NGINX_RAW_APPEND

  nginx::resource::server { 'ontoportal_web_ui':
    ensure         => present,
    server_name    => [$domain] + $slices_fqdn,
    listen_port    => $port,
    listen_options => $_catch_all,
    www_root       => "${app_dir}/current/public",
    try_files      => ['$uri/index.html', '$uri', '@puma-bioportal_web_ui'],
    ssl_redirect   => $_enable_https_redirect,
    index_files    => [],
    ssl            => $enable_ssl,
    ssl_cert       => $_ssl_cert,
    ssl_key        => $_ssl_key,
    raw_append     => $raw_append,
  }

  nginx::resource::location { '@puma-bioportal_web_ui':
    ssl                => $enable_ssl,
    ssl_only           => $_enable_https_redirect,
    proxy_http_version => '1.1',
    server             => 'ontoportal_web_ui',
    proxy              => 'http://puma-bioportal_web_ui',
    proxy_set_header   => [
      'X-Forwarded-For $proxy_add_x_forwarded_for',
      'Host $host',
      'X-Forwarded-Proto https',
      'X-Real-IP $remote_addr',
    ],
  }

}

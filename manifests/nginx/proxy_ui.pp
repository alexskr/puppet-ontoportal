class ontoportal::nginx::proxy_ui (
  Stdlib::Host $domain,
  Boolean $catch_all               = true, #must be disabled for canonical redirect or block all non-canonical domains
  Integer $logrotate_nginx         = 180,
  Stdlib::Absolutepath $app_dir,
  Optional[Array[String]] $slices  = [], #used as SAN for letsencrypt
  Optional[Stdlib::Absolutepath] $ssl_key,
  Optional[Stdlib::Absolutepath] $ssl_cert,
  Boolean $manage_letsencrypt      = false,
  Boolean $enable_https            = true,
  Boolean $enable_https_redirect   = $enable_https,
  Stdlib::Port $port               = 80,
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

  $_ssl_cert = ontoportal::tls_path($domain, 'cert', $ssl_cert)
  $_ssl_key  = ontoportal::tls_path($domain, 'key',  $ssl_key)

  $_enable_https_redirect = $enable_https and $enable_https_redirect

  # static files / assets file are served by nginx
  nginx::resource::location { '^~ /assets/':
    ensure      => present,
    ssl         => $enable_https,
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
    listen_options => bool2str($catch_all, 'default_server', ''),
    www_root       => "${app_dir}/current/public",
    try_files      => ['$uri/index.html', '$uri', '@puma-bioportal_web_ui'],
    ssl_redirect   => $_enable_https_redirect,
    index_files    => [],
    ssl            => $enable_https,
    ssl_cert       => $_ssl_cert,
    ssl_key        => $_ssl_key,
    raw_append     => $raw_append,
  }

  nginx::resource::location { '@puma-bioportal_web_ui':
    ssl                => $enable_https,
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

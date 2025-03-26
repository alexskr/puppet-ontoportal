#
# Class: ncbo::profile::bioportal_web_ui
#
# Description: This class manages bioportal_Web_ui, nginx/puma/rails setup for bioportal web ui
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class ontoportal::bioportal_web_ui (
  Enum['staging', 'production', 'appliance', 'development'] $environment = 'staging',
  String $ruby_version             = '3.1.6',
  String $owner                    = 'ontoportal',
  String $group                    = 'ncbo',
  Boolean $enable_nginx_status     = true,
  Integer $logrotate_nginx         = 400,
  Integer $logrotate_rails         = 14,
  Integer $puma_workers            = $facts['processors']['count']/2,
  Stdlib::Absolutepath $app_root   = '/opt/ontoportal/bioportal_web_ui',
  $domain                          = 'demo.ontoportal.org',
  $slices = [], #used as SAN for letsencrypt
  Stdlib::Absolutepath $ssl_cert   = "/etc/letsencrypt/live/${domain}/cert.pem",
  Stdlib::Absolutepath $ssl_key    = "/etc/letsencrypt/live/${domain}/privkey.pem",
  Stdlib::Absolutepath $ssl_fullchain = "/etc/letsencrypt/live/${domain}/fullchain.pem",
  Boolean $manage_letsencrypt      = false,
  Boolean $enable_https            = true,
  Boolean $enable_https_redirect   = true,
  Boolean $install_ruby            = true,
  Stdlib::Port $port               = 80,
  Boolean $manage_nginx_repo       = false,
  Stdlib::Absolutepath $bundle_bin = '/usr/local/rbenv/shims/bundle',
) {
  include ontoportal::firewall::http

  case $facts['os']['family'] {
    'RedHat': {
      require epel
      stdlib::ensure_packages ([
        'mariadb-devel',
      ])
    }
    'Debian': {
      stdlib::ensure_packages ([
        'libmariadb-dev',
        'tzdata',
      ])
    }
  }

  include ontoportal::yarn

  if $install_ruby {
    ontoportal::rbenv { $ruby_version:
      global => true,
      # rubygems_version => '3.5.16',
      # bundler_version  => '2.5.16',
    }
  }

  file { '/var/log/rails':
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0770';
  }

  #Create rails directory structure
  file {
    default:
      ensure => directory,
      owner  => $owner,
      group  => $group;
    [$app_root ,"${app_root}/shared","${app_root}/releases", "${app_root}/shared/system", "${app_root}/shared/tmp","${app_root}/shared/tmp/sockets"]:
      mode   => '0775';
    ["${app_root}/shared/log"]:
      ensure => 'link',
      target => '/var/log/rails',
      force  => yes;
  }

  logrotate::rule { 'rails':
    path          => '/var/log/rails/*.log',
    rotate        => $logrotate_rails,
    size          => '10M',
    delaycompress => true,
    copytruncate  => true,
    ifempty       => false,
    dateext       => true,
    compress      => true,
    missingok     => true,
    # su          => true,
    su_user       => $owner,
    su_group      => $group,
    postrotate    => "kill -HUP `cat ${app_root}/shared/tmp/pids/puma.pid`", #puma
  }

  $slices_fqdn = $slices.map |$item| { "${item}.${domain}" }
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

  ontoportal::puma { 'ui':
    owner        => $owner,
    group        => $group,
    app_root     => $app_root,
    bundle_bin   => $bundle_bin,
    rails_env    => $environment,
    # environment  => undef,
    # puma_threads => undef,
    puma_workers => $puma_workers,
  }

  include ontoportal::nginx

  # static files / assets file are served by nginx
  nginx::resource::location { '^~ /assets/':
    ensure      => present,
    ssl         => $enable_ssl,
    ssl_only    => $_enable_https_redirect,
    www_root    => "${app_root}/current/public",
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
        server       => "unix:${app_root}/shared/tmp/sockets/puma.sock",
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
    listen_options => 'default_server',
    www_root       => "${app_root}/current/public",
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
    proxy_http_version => ' 1.1',
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

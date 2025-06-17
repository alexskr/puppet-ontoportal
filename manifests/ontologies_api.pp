#
# Description: This class manages API/rest (ontologies_api) intra for ontoportal
#
class ontoportal::ontologies_api (
  Enum['staging', 'production', 'appliance', 'development'] $environment = 'staging',
  Boolean $manage_ruby            = true,
  String $ruby_version             = '3.1.6',
  String $admin_user               = 'op-admin',
  String $service_account          = 'op-backend',
  Boolean $manage_service_account  = true,
  String $data_group               = 'opdata',
  Integer $logrotate_nginx         = 180,
  Integer $logrotate_unicorn       = 180,
  Stdlib::Host $domain             = 'data.demo.ontoportal.org',
  $slices = [], #used as SAN for letsencrypt
  Boolean $enable_https            = true,
  Boolean $enable_https_redirect   = true,
  Boolean $manage_letsencrypt      = false,

  Stdlib::Absolutepath $app_root_dir = '/opt/ontoportal',
  Stdlib::Absolutepath $app_dir    = "${app_root_dir}/ontologies_api",
  Stdlib::Absolutepath $bundle_bin = '/usr/local/rbenv/shims/bundle',
  Stdlib::Absolutepath $log_dir    = '/var/log/ontoportal/ontologies_api',
  Stdlib::Absolutepath $ssl_cert   = "/etc/letsencrypt/live/${domain}/cert.pem",
  Stdlib::Absolutepath $ssl_key    = "/etc/letsencrypt/live/${domain}/privkey.pem",
  Stdlib::Absolutepath $ssl_fullchain = "/etc/letsencrypt/live/${domain}/fullchain.pem",

  Boolean $manage_java            = true,
  String $java_version             = 'openjdk-11-jre-headless',
  Stdlib::Port $port               = 80,
  Stdlib::Port $port_https         = 443,
  Boolean $enable_nginx_status     = false,
  Boolean $manage_nginx_repo       = true,
  Boolean $manage_firewall         = true,
  Stdlib::Absolutepath $data_dir   = '/srv/ontoportal',
) {
  case $facts['os']['family'] {
    # redhat is not fully supported
    'RedHat': {
      selinux::boolean { 'httpd_can_sendmail': }
      selinux::boolean { 'httpd_can_network_connect': }
      require epel
      stdlib::ensure_packages ([
        'libxml2-devel', # for xml gem
      ])
      Class[epel] -> Class[nginx]
    }
    'Debian': {
      stdlib::ensure_packages ([
        'file', # needed by oLD mime detection
        'libxml2-dev',
        'raptor2-utils', # W: [strict_indent] indent should be 10 chars and is 8
      ])
    }
  }

  include ontoportal::nginx

  if $manage_firewall {
    firewall_multi { "34 allow inbound API on port ${port} and ${port_https}":
      dport => [$port, $port_https],
      proto => tcp,
      jump  => accept,
    }
  }

  # ontoportal ops/deployer user needs sudo to restart unicorn on deployments
  sudo::conf { 'unicorn':
    priority => 55,
    content  => "${admin_user} ALL=(ALL) NOPASSWD: /bin/systemctl stop unicorn, /bin/systemctl start unicorn, /bin/systemctl restart unicorn",
  }

  if $manage_service_account {
    include ontoportal::user::backend
  }

  #paths
  file { [$app_dir, "${app_dir}/shared" ]:
    ensure => directory,
    owner  => $admin_user,
    group  => $data_group,
    mode   => '0750',
  }
  -> file { [$log_dir]:
    ensure => directory,
    owner  => $service_account,
    group  => $data_group,
    mode   => '0770',
  }
  -> file { "${app_dir}/shared/log":
    ensure => link,
    target => $log_dir,
  }

  if $manage_ruby and !defined(Ontoportal::Rbenv[$ruby_version]) {
    ontoportal::rbenv { $ruby_version: }
  }

  nginx::resource::upstream { 'ontologies_api':
    members => {
      'api' => {
        server       => "unix:/run/unicorn/unicorn.sock",
        fail_timeout => '0s',
      },
    },
  }
  # enable https redirect only if we have valid certs
  #$_enable_https_redirect = $enable_https and $enable_https_redirect and $manage_letsencrypt
  $_enable_https_redirect = $enable_https and $enable_https_redirect and $manage_letsencrypt
  if $enable_https and $manage_letsencrypt {
    $_san = $slices.map |$item| { "${item}.${domain}" }
    ontoportal::letsencrypt { $domain:
      cron_success_command => '/bin/systemctl reload nginx.service',
      domain               => $domain,
      san                  => $_san,
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

  # don't enable default server for nginx if its running on standard ports,
  # just in case UI is running on the same machine
  $listen_options = ($port == 80 and $port_https == 443) ? {
    true  => undef,
    false => 'default_server',
  }

  nginx::resource::server { 'ontologies_api':
    ensure           => present,
    server_name      => [$domain, "*.${domain}"],
    listen_port      => $port,
    ssl_port         => $port_https,
    listen_options   => $listen_options,
    proxy            => 'http://ontologies_api' ,
    index_files      => [],
    ssl              => $enable_ssl,
    ssl_redirect     => $_enable_https_redirect,
    ssl_cert         => $_ssl_cert,
    ssl_key          => $_ssl_key,
    proxy_set_header => ['X-Forwarded-For $proxy_add_x_forwarded_for', 'Host $http_host', 'X-Real-IP $remote_addr'],
  }

  # java is required for owlapi_wrapper
  if $manage_java {
    class { 'java':
      package => $java_version,
    }
  }

  $read_write_paths = [
    '/run/unicorn', # pid, socket
    $log_dir,
    "${data_dir}/repository",
    "${data_dir}/reports", # api can refresh reports. although that functionality should be moved to ncbo_cron
  ]

  $read_only_paths = [
    #  "/opt/ontoportal/virtual_appliance/utils", #contains ip look up util.  or maybe its better to move it to /usr/local/bin?
#    "${app_dir}/config", # contains site_config.rb
#    "${app_dir}/current", # app lives here
  ]

  systemd::unit_file { 'unicorn.service':
    ensure  => 'present',
    content => epp ('ontoportal/unicorn.service.epp', {
        'user'             => $service_account,
        'group'            => $data_group,
        'app_dir'          => $app_dir,
        'bundle_bin'       => $bundle_bin,
        'environment'      => $environment,
        'read_only_paths'  => $read_only_paths,
        'read_write_paths' => $read_write_paths,
    }),
  }
  ~> service { 'unicorn':
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  logrotate::rule { 'unicorn':
    path         => "${log_dir}/*.log",
    rotate       => $logrotate_unicorn,
    rotate_every => 'day',
    copytruncate => true,
    dateext      => true,
    compress     => true,
    missingok    => true,
    su           => true,
    su_user      => $service_account,
    su_group     => $service_account,
  }
}

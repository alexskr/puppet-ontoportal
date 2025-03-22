#
# Description: This class manages API/rest intra for ontoportal
#
class ontoportal::ontologies_api (

  Enum['staging', 'production', 'appliance', 'development'] $environment = 'staging',
  Boolean $install_ruby            = true,
  String $ruby_version             = '3.1.6',
  String $owner                    = 'ontoportal',
  String $group                    = 'ontoportal',
  Integer $logrotate_nginx         = 180,
  Integer $logrotate_unicorn       = 180,
  Stdlib::Absolutepath $app_root   = '/opt/ontoportal/ontologies_api',
  Stdlib::Host $domain             = 'data.demo.ontoportal.org',
  $slices = [], #used as SAN for letsencrypt
  Boolean $ssl_redirect            = false,
  Boolean $enable_letsencrypt      = false,
  Stdlib::Absolutepath $ssl_cert   = "/etc/letsencrypt/live/${domain}/cert.pem",
  Stdlib::Absolutepath $ssl_key    = "/etc/letsencrypt/live/${domain}/privkey.pem",
  Stdlib::Absolutepath $ssl_chain  = "/etc/letsencrypt/live/${domain}/fullchain.pem",
  Stdlib::Absolutepath $bundle_bin = '/usr/local/rbenv/shims/bundle',
  Boolean $install_java            = true,
  String $java_version             = 'openjdk-11-jre-headless',
  Stdlib::Port $port               = 80,
  Stdlib::Port $port_https         = 443,
  Boolean $enable_https            = true,
  Boolean $enable_nginx_status     = false,
  Boolean $manage_nginx_repo       = true,
  Boolean $manage_firewall         = true,
  Stdlib::Absolutepath $data_dir   = '/srv/ontoportal',
  Stdlib::Absolutepath $le_www_root = '/mnt/.letsencrypt',
) {

  case $facts['os']['family'] {
    'RedHat': {
      selinux::boolean { 'httpd_can_sendmail': }
      selinux::boolean { 'httpd_can_network_connect': }
      require epel
      ensure_packages ([
        'libxml2-devel', # for xml gem
      ])
      Class[epel] -> Class[nginx]
    }
    'Debian': {
      ensure_packages ([
        'libxml2-dev'
      ])
    }
  }

  include ontoportal::nginx

  if $manage_firewall {
    firewall_multi { "34 allow inbound API on port ${port} and $ssl_port":
      dport => [$port, $ssl_port],
      proto => tcp,
      jump  => accept,
    }
  }

  # ontoportal/deployer user needs sudo to restart unicorn on deployments
  sudo::conf { 'unicorn':
    priority => 55,
    content  => "${owner} ALL=(ALL) NOPASSWD: /bin/systemctl stop unicorn, /bin/systemctl start unicorn, /bin/systemctl restart unicorn",
  }

  File {
    owner => 'root',
    group => $group,
    mode  => '0775',
  }

  #paths
  file { [$app_root]:
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0775',
  }

  if $install_ruby and !defined(Ontoportal::Rbenv[$ruby_version]) {
    ontoportal::rbenv{ $ruby_version: }
  }

  nginx::resource::upstream { 'ontologies_api':
    members => {
      'api' => {
        server       => "unix:${app_root}/shared/tmp/sockets/unicorn.sock",
        fail_timeout => '0s',
      },
    },
  }

  if $enable_https and $enable_letsencrypt {
    $_san = $slices.map |$item| { "${item}.${domain}" }
    ontoportal::letsencrypt { $domain:
      cron_success_command => '/bin/systemctl reload nginx.service',
      domain               => $domain,
      san                  => $_san,
    }
  }

  # enable TLS if letsencrypt cert is generated.  FIXME This requires second puppet run so this should be refactored
  if $enable_letsencrypt {
    $_enable_ssl = $domain in $facts['letsencrypt_directory']
    $_ssl_cert  = $ssl_cert
    $_ssl_chain = $ssl_chain
    $_ssl_key   = $ssl_key
  } else {
    $_enable_ssl = $enable_https
    # set to a locally generated cert so that nginx doesn't fall over before we get our cert
    $_ssl_cert  = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
    $_ssl_chain = '/etc/ssl/certs/ca-certificates.crt'
    $_ssl_key   = '/etc/ssl/private/ssl-cert-snakeoil.key'
  }

  nginx::resource::server { 'ontologies_api':
    ensure           => present,
    server_name      => [$domain, "*.${domain}"],
    listen_port      => $port,
    ssl_port         => $port_https,
    listen_options   => 'default_server',
    proxy            => 'http://ontologies_api' ,
    index_files      => [],
    ssl              => $_enable_ssl,
    ssl_redirect     => $ssl_redirect,
    ssl_cert         => $_ssl_cert,
    ssl_key          => $_ssl_key,
    proxy_set_header => ['X-Forwarded-For $proxy_add_x_forwarded_for', 'Host $http_host', 'X-Real-IP $remote_addr'],
  }

  #java required for owlapi/owl validation
  if $install_java {
    class { 'java':
      package => $java_version,
    }
  }

  systemd::unit_file { 'unicorn.service':
    ensure  => 'present',
    content => epp ('ontoportal/unicorn.service.epp', {
        'user'        => $owner,
        'group'       => $group,
        'app_root'    => $app_root,
        'bundle_bin'  => $bundle_bin,
        'environment' => $environment,
    }),
  }
  ~> service { 'unicorn':
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  logrotate::rule { 'unicorn':
    path         => "${app_root}/current/log/*.log",
    rotate       => $logrotate_unicorn,
    rotate_every => 'day',
    copytruncate => true,
    dateext      => true,
    compress     => true,
    missingok    => true,
    su           => true,
    su_user      => $owner,
    su_group     => $group,
  }
}

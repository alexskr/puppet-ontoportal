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

class ontoportal::ontologies_api(

  Enum[ 'staging', 'production', 'appliance', 'development'] $environment = 'staging',
  Boolean $install_ruby            = true,
  String $ruby_version             = '2.6.7',
  String $owner                    = 'ontoportal',
  String $group                    = 'ontoportal',
  Integer $logrotate_nginx         = 180,
  Integer $logrotate_unicorn       = 180,
  Stdlib::Absolutepath $app_root   = '/srv/ontoportal/ontologies_api',
  Stdlib::Host $domain             = 'data.ontoportal.org',
  $slices = [ 'bis', 'ctsa', 'biblio', 'psi', 'cabig', 'cgiar', 'umls', 'who-fic' ], #used as SAN for letsencrypt, obo_foundary is problematic since it has underscore;
  Boolean $ssl_redirect            = false,
  Stdlib::Absolutepath $ssl_cert   = "/etc/letsencrypt/live/${domain}/cert.pem",
  Stdlib::Absolutepath $ssl_key    = "/etc/letsencrypt/live/${domain}/privkey.pem",
  Stdlib::Absolutepath $ssl_chain  = "/etc/letsencrypt/live/${domain}/fullchain.pem",
  Stdlib::Absolutepath $bundle_bin = '/usr/local/rbenv/shims/bundle',
  Boolean $install_java            = true,
  String $java_version             = 'java-11-openjdk-headless',
  Stdlib::Port $port               = 80,
  Boolean $enable_ssl              = true, #not nessesary for appliance
  Boolean $enable_nginx_status     = true, #not requried for appliance
  Boolean $manage_nginx_repo       = true,
  Boolean $manage_firewall         = true,
  Stdlib::Absolutepath $data_dir   = '/srv/ontoportal',
  Stdlib::Absolutepath $le_www_root = '/mnt/.letsencrypt',
  ) {

  if ($facts['os']['family'] != 'RedHat') or ($facts['os']['release']['major'] != '7') {
    fail ('this module supports only EL7')
  }

  require epel

  Class[epel] -> Class[nginx]
  selinux::boolean { 'httpd_can_sendmail': }
  selinux::boolean { 'httpd_can_network_connect': }

  if $manage_firewall {
    firewall_multi { "34 allow inbound API on port ${port}":
      dport  => $port,
      proto  => tcp,
      action => accept,
    }
  }
  ensure_packages ([
    'mariadb-devel', # for mysql2 gem
    'libxml2-devel', # for xml gem
  ])

  # ontoportal/deployer user needs sudo to restart unicorn on deployments
  sudo::conf { 'unicorn':
    priority => 55,
    content  =>  "${owner} ALL=(ALL) NOPASSWD: /bin/systemctl stop unicorn, /bin/systemctl start unicorn, /bin/systemctl restart unicorn",
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

  # FIXME move autofs to role
  if $environment != 'appliance' {
    file { ["${data_dir}/repository" ]:
      ensure => link,
      target => "/srv/ncbo/share/env/${environment}/repository"
    }
    require profile::autofs::ncbo_share
  }

  #required for building some of the ruby gems
  if $install_ruby {
    class { 'ontoportal::rbenv':
      ruby_version => $ruby_version,
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

  nginx::resource::upstream { 'ontologies_api':
    members => {
      'localhost' => {
        server       => "unix:${app_root}/shared/tmp/sockets/unicorn.sock",
        fail_timeout => '0s',
    },}
  }

  nginx::resource::location { 'letsencrypt':
    ensure              => present,
    ssl                 => false,
    server              => 'ontologies_api',
    index_files         => [],
    location            => '^~ /.well-known/acme-challenge/',
    www_root            => $le_www_root ,
    location_cfg_append => {
      default_type => 'text/plain', },
  }

  if  $enable_ssl {
    # FIXME move autofs to role
    require profile::autofs::ncbo_le
    $_san = $slices.map |$item| { "${item}.${domain}" }
    ontoportal::letsencrypt { $domain:
      cron_success_command => '/bin/systemctl reload nginx.service',
      domain               => $domain,
      san                  => $_san,
    }
  }

  # enable TLS if letsencrypt cert is generated.  FIXME This requires second puppet run so this should be refactored
  $enable_tls = $domain in $facts['letsencrypt_directory']


  nginx::resource::server { 'ontologies_api':
    ensure           => present,
    server_name      => [$domain, "*.${domain}", $::fqdn],
    listen_port      => $port,
    listen_options   => 'default_server',
    proxy            => 'http://ontologies_api' ,
    index_files      => [],
    ssl              => $enable_tls,
    ssl_redirect     => $ssl_redirect,
    ssl_cert         => $ssl_chain,
    ssl_key          => $ssl_key,
    proxy_set_header => [ 'X-Forwarded-For $proxy_add_x_forwarded_for', 'Host $http_host', 'X-Real-IP $remote_addr' ],
    # ssl_session_cache => 'shared:SSL:10m',
  }

  if $enable_nginx_status  {
    nginx::resource::location { '/nginx_status':
      ensure         => present,
      server         => 'ontologies_api',
      ssl            => false,
      stub_status    => true,
      location_allow => [ '127.0.0.1' ],
      location_deny  => ['all'],
    }
  }

  #java required for owlapi/owl validation
  if $install_java {
    class { 'java':
      package => $java_version
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

  # FIXME move log shippment to role
  if $environment == 'production' {
    file { ['/etc/cron.d/ontologies_api_copy_logs']:
      ensure  => present,
      content => "00 01 * * * ${owner} mv ${app_root}/shared/log/production.*.gz /srv/ncbo/share/env/production/logs/rest/${trusted['hostname']}/pending > /dev/null 2>&1
00 02 * * * ${owner} find ${app_root}/shared/log/*.gz -mtime +7 -delete > /dev/null 2>&1/n",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
    }
  }
}



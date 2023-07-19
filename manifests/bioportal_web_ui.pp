#
# Class: ncbo::profile::bioportal_web_ui
#
# Description: This class manages bioportal_Web_ui, apache/passenger/rails setup for bioportal web ui
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
  String $ruby_version            = '2.7.8',
  String $owner                   = 'ontoportal',
  String $group                   = 'ontoportal',
  Boolean $enable_mod_status      = true,
  Integer $logrotate_httpd        = 400,
  Integer $logrotate_rails        = 14,
  Stdlib::Absolutepath $railsdir  = '/srv/ontoportal/bioportal_web_ui',
  Stdlib::Host $domain            = 'stage.bioontology.org',
  Array $slices = ['www', 'bis', 'ctsa', 'biblio', 'psi', 'cabig', 'cgiar', 'obo-foundry', 'umls', 'who-fic'], #used as SAN for letsencrypt
  Stdlib::Absolutepath $ssl_cert  = "/etc/letsencrypt/live/${domain}/cert.pem",
  Stdlib::Absolutepath $ssl_key   = "/etc/letsencrypt/live/${domain}/privkey.pem",
  Stdlib::Absolutepath $ssl_chain = "/etc/letsencrypt/live/${domain}/chain.pem",
  Boolean $enable_ssl             = true,
  Boolean $manage_letsencrypt     = false,
  Boolean $ssl_redirect           = false,
  Boolean $install_ruby           = true,
  Boolean $canonical_redirect     = true
) inherits ontoportal::params {
  include ontoportal::firewall::http

  if $facts['os']['family'] == 'RedHat' {
    require epel
  }

  class { 'nodejs': }
  class { 'yarn': }

  class { 'apache':
    default_vhost    => false,
    manage_user      => false,
    manage_group     => false,
    trace_enable     => 'Off',
    server_signature => 'Off',
    default_mods     => false,
    mpm_module       => 'worker',
    require          => File['/srv/ontoportal'],
  }

  apache::listen { '80': }
  class { 'apache::mod::headers': }
  class { 'apache::mod::ssl': }
  class { 'apache::mod::xsendfile': }
  class { 'apache::mod::rewrite': }
  class { 'apache::mod::deflate': }
  class { 'apache::mod::expires': }
  class { 'apache::mod::dir': }
  class { 'apache::mod::passenger':
    passenger_root                          => '/usr/share/ruby/vendor_ruby/phusion_passenger/locations.ini', #EL7 EPEL based mod_passenger config
    passenger_default_ruby                  => "/usr/local/rbenv/versions/${ruby_version}/bin/ruby",
    #  passenger_high_performance           => 'on',  #breaks mod_rewrite and PassengerEnabled off for widgets
    passenger_max_pool_size                 => 30,
    passenger_max_requests                  => 1000,
    passenger_allow_encoded_slashes         => 'on',
    # security related:
    passenger_show_version_in_header        => 'off',
    passenger_disable_anonymous_telemetry   => true,
    passenger_disable_security_update_check => 'on',
  }

  if $enable_mod_status {
    class { 'apache::mod::status':
      requires => ['ip 127.0.0.1 172.27.213.0/24 10.111.30.32'],
    }
  }

  # in place to mitigate https://tickets.puppetlabs.com/browse/MODULES-5612
  file {
    ['/etc/httpd/conf.modules.d/00-mpm.conf',
      '/etc/httpd/conf.modules.d/00-ssl.conf',
      '/etc/httpd/conf.modules.d/00-systemd.conf',
      '/etc/httpd/conf.modules.d/10-passenger.conf',
    ]:
      mode    => '0644',
      owner   => root,
      group   => root,
      content => '# placeholder in place to mitigate https://tickets.puppetlabs.com/browse/MODULES-5612\n',
  }

  if $install_ruby {
    class { 'ontoportal::rbenv':
      ruby_version => $ruby_version,
    }
  }

  ensure_packages ([
      $ontoportal::params::pkg_mariadb_dev,
      'passenger-devel',  #required for compiling passenger_native_support.so for the current Ruby interpreter
  ])
  # redirect for maintenance
  $maintanence_rewrite = {
    'rewrite_cond' => ['%{DOCUMENT_ROOT}/system/maintenance.html -f',
      '%{SCRIPT_FILENAME} !/system/maintenance.html',
      '%{REQUEST_URI} !/system/maintenance.html$'],
    'rewrite_rule' => '^.*$ /system/maintenance.html [L]' }
  $slices_fqdn = $slices.map |$item| { "${item}.${domain}" }

  if $enable_ssl {
    if $manage_letsencrypt {
      ontoportal::letsencrypt { $domain:
        domain => $domain,
        san    => $slices_fqdn,
      }
    }

    if $ssl_redirect {
      $_rewrites = {
        'rewrite_cond' => '%{REQUEST_URI} !(\.well-known/acme-challenge|/server-status)',
        'rewrite_rule' => '^/?(.*) https://%{SERVER_NAME}/$1 [R,L]',
      }
    } else {
      $_rewrites = $maintanence_rewrite
    }
    $alias_le = { alias => '/.well-known/acme-challenge/',
                  path  => '/mnt/.letsencrypt/.well-known/acme-challenge/' }
    $directories_le = {
      path              => '/mnt/.letsencrypt/.well-known/acme-challenge',
      require           => 'all granted',
      #options          => 'MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec',
      # Require method GET POST OPTIONS
      passenger_enabled => 'off',
      allow_override    => 'None',
    }
  } else {
    $alias_le = undef
    $directories_le = undef
    $_rewrites = {}
  }
  #site
  $_docroot = "${railsdir}/current/public"
  if $environment == 'appliance' {
    $_custom_fragment = 'ontoportal/bioportal_web_ui-httpd-appliance-fragment.erb'
  } else {
    $_custom_fragment = 'ontoportal/bioportal_web_ui-httpd-fragment.erb'
  }
  apache::vhost { "${domain}_non-tls":
    servername            => $domain,
    serveraliases         => $slices_fqdn,
    port                  => 80,
    default_vhost         => true,
    docroot               => $_docroot,
    manage_docroot        => false,
    aliases               => [$alias_le],
    directories           => [$directories_le],
    rewrites              => [$maintanence_rewrite, $_rewrites],
    custom_fragment       => template($_custom_fragment),
    passenger_app_env     => $environment,
    passenger_ruby        => "/usr/local/rbenv/versions/${ruby_version}/bin/ruby",
    allow_encoded_slashes => 'nodecode',
  }

  if $enable_ssl {
    apache::listen { '443': }
    apache::vhost { "${domain}_tls":
      servername            => $domain,
      serveraliases         => $slices_fqdn,
      port                  => 443,
      default_vhost         => true,
      ssl                   => true,
      passenger_ruby        => "/usr/local/rbenv/versions/${ruby_version}/bin/ruby",
      ssl_cert              => $ssl_cert,
      ssl_key               => $ssl_key,
      ssl_chain             => $ssl_chain,
      docroot               => $_docroot,
      manage_docroot        => false,
      passenger_app_env     => $environment,
      allow_encoded_slashes => 'nodecode',
      custom_fragment       => template($_custom_fragment),
    }
  }
  file { '/srv/rails':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755';
    '/var/log/rails':
      ensure => directory,
      owner  => $owner,
      group  => $group,
      mode   => '0770';
  }

  #Create rails directory structure
  -> file {
    default:
      ensure => directory,
      owner  => $owner,
      group  => $group;
    [$railsdir ,"${railsdir}/shared","${railsdir}/releases", "${railsdir}/shared/system"]:
      mode   => '0775';
    ["${railsdir}/shared/log"]:
      ensure => 'link',
      target => '/var/log/rails',
      force  => yes;
  }

  logrotate::rule { 'httpd':
    path       => '/var/log/httpd/*log',
    rotate     => $logrotate_httpd,
    size       => '10M',
    dateext    => true,
    compress   => true,
    missingok  => true,
    postrotate => '/sbin/service httpd reload > /dev/null 2>/dev/null || true',
  }

  logrotate::rule { 'bioportal_web_ui_rails':
    path       => '/var/log/rails/*.log',
    rotate     => $logrotate_rails,
    size       => '10M',
    dateext    => true,
    compress   => true,
    missingok  => true,
    su         => true,
    su_user    => $owner,
    su_group   => $group,
    postrotate => '/sbin/service httpd reload > /dev/null 2>/dev/null || true',
  }
}

#
# Class: ncbo::purl

# Description: This class manages purl server
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class ontoportal::purl(
  Stdlib::Host $vhost                   = 'purl.bioontology.org',
  Stdlib::Absolutepath $purl_path = '/usr/local/PURLZ-Server-1.6.3',
  Boolean $https_redirect         = false,
  ){

  user { 'purl':
    ensure           => 'present',
    comment          => 'Purl Server',
    home             => "${purl_path}/bin",
    password         => '!!',
    password_max_age => '-1',
    password_min_age => '-1',
    shell            => '/bin/bash',
    system           => true,
  }
  group { 'purl':
    ensure => 'present',
    system => true,
  }
  class { 'profile::mysql':
    key_buffer_size  => '64m',
  }
  mysql_user { 'purls@localhost':
    ensure        => 'present',
    password_hash => '*AD10BD50BEF395EF2CADF200ED99C20172373D8C',
  }
  -> mysql_database {'purls': ensure   =>  present, }
  -> mysql_grant { 'purls@localhost/purls.*':
    ensure     => 'present',
    privileges => ['ALTER', 'CREATE', 'CREATE TEMPORARY TABLES', 'DELETE', 'INDEX', 'INSERT', 'LOCK TABLES', 'SELECT' ],
    table      => 'purls.*',
    user       => 'purls@localhost',
  }
  -> class { 'profile::mysql::automysqlbackup': }
  class { 'java':
    package =>  'java-1.8.0-openjdk-headless'
  }
  -> file { '/var/log/purlz/':
    ensure => directory,
    mode   => '0755',
    owner  => 'purl',
    group  => 'purl',
  }
  #r10k doesn't support git lfs; the workaround is to keep .tgz file outside of repo
  -> archive { "${purl_path}.tgz":
    source       => 'puppet:///modules/bmir/ncbo/purl/PURLZ-Server-1.6.3.tgz',
    extract_path => '/usr/local',
    extract      => true,
    creates      => "${purl_path}/bin",
    cleanup      => true,
  }
  -> file { "${purl_path}/log":
    ensure => link,
    target => '/var/log/purlz',
    force  => true,
  }

  #blocking /admin /docs pages for security reasons
  $custom_template = '
  <LocationMatch "^/(admin|docs)">
    Require all denied
    Require ip 172.27.213.0/24
    Require ip 171.66.176.0/20
    Require ip 171.66.16.0/21
    Require ip 171.66.24.0/21
    Require ip 127.0.0.1
  </LocationMatch>
  '
  #Apache Proxy
  include profile::firewall::http
  include profile::apache::server
  profile::apache::reverseproxy { $vhost :
    letsencrypt     => true,
    https_redirect  => $https_redirect,
    proxy_timeout   => 60,
    custom_fragment => $custom_template,
  }

  file { '/etc/init.d/purl':
    ensure => symlink,
    target => "${purl_path}/bin/netkernel"
  }

  service { 'purl':
    ensure  => 'running',
    enable  => 'true',
    require => File['/var/log/purlz/', '/etc/init.d/purl']
  }

  #purl server is notoriously flaky; so we are keeping it up and running with monit
  include monit
  monit::check { 'purl':
    content => 'check process purl
    matching "com\.ten60\.netkernel\.bootloader\.BootLoader"
    start program = "/etc/init.d/purl start" with timeout 60 seconds
    stop program  = "/etc/init.d/purl stop" with timeout 120 seconds
    if failed host localhost port 8080 
      protocol HTTP request "/docs/index.html" then restart
   ',
  }
}

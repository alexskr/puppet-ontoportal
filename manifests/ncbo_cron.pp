#
# Class: ncbo::ncbo_cron
#
# Description: This class manages ncbo_cron
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class ontoportal::ncbo_cron (
  String $environment            = 'appliance',
  String $service_account        = 'op-backend',
  String $admin_user             = 'op-admin',
  String $group                  = 'opdata',
  Stdlib::Absolutepath $app_dir  = '/opt/ontoportal/ncbo_cron',
  Stdlib::Absolutepath $log_dir  = '/var/log/ontoportal/ncbo_cron',
  $service                       = 'running',
  Stdlib::Absolutepath $data_dir = '/srv/ontoportal',
  Stdlib::Absolutepath $repo_dir = "${data_dir}/repository",
  Array[Stdlib::Absolutepath] $read_write_paths = [ $repo_dir, "${data_dir}/mgrep", "${data_dir}/reports", "${data_dir}/web_analytics"],
  String $ruby_version           = '3.1.6',
  Integer $logrotate_days        = 356,
  Boolean $manage_java           = true,
  Boolean $manage_ruby           = true,
  String $java_version           = 'openjdk-11-jre-headless',
) {
  require ontoportal::params
  case $facts['os']['family'] {
    'RedHat': {
      require epel
      require librdf::raptor2
    }
    'Debian': {
      stdlib::ensure_packages([
        'file', # needed by oLD MIME detection
        'libwww-perl', # needed for 4s-dump
        'libxml2-dev',
        'raptor2-utils',
      ])
    }
  }

  if $manage_ruby and !defined(Ontoportal::Rbenv[$ruby_version]) {
    ontoportal::rbenv { $ruby_version:
      global =>  true,
    }
  }

  file { $app_dir:
    ensure  => directory,
    owner   => $admin_user,
    group   => $group ,
    mode    => '0750',
    require => Service['ncbo_cron'],
  }
  -> file { $log_dir:
    ensure => directory,
    owner  => $service_account,
    group  => $group,
    mode   => '0750',
  }
  -> file { "${app_dir}/log":
    ensure => link,
    target => $log_dir,
  }

  file { $repo_dir:
    ensure => directory,
    owner  => $service_account,
    group  => $group,
    mode   => '2770',
  }

  #/tmp clean up script - Deletes files that ncbo_cron is too lazy to delete
  # we are using systemd private tmp
  file { ['/etc/cron.d/ncbo_cron_tmpclean']:
    ensure  => present,
    content => '00 05 * * * root find /tmp/systemd-private-*-ncbo_cron.service-*/tmp/* ! -name ruby-uuid -mtime +1 -delete\n',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  #java required for owlapi/owl validation
  if $manage_java {
    class { 'java':
      package => $java_version,
    }
  }
  systemd::tmpfile { 'ncbo_cron.conf':
    ensure  => present,
    content => "d /run/ncbo_cron 0755 $service_account $group"
  }

  systemd::unit_file { 'ncbo_cron.service':
    content => epp('ontoportal/ncbo_cron.service.epp', {
        app_dir          => $app_dir,
        user             => $service_account,
        group            => $group,
        read_write_paths => $log_dir + $read_write_paths,
        }),
  }
  ~> service { 'ncbo_cron':
    # ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  logrotate::rule { 'ncbo_cron':
    path         => "${log_dir}/*.log",
    rotate       => $logrotate_days,
    minsize      => '10M',
    rotate_every => 'day',
    copytruncate => true,
    dateext      => true,
    compress     => true,
    missingok    => true,
    su           => true,
    su_user      => $service_account,
    su_group     => $group,
  }
}

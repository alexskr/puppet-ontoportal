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

class ontoportal::ncbo_cron(
  $environment          = 'staging',
  $owner                = 'ncbo-deployer',
  $group                = 'ncbo-deployer',
  $app_root             = '/srv/ontoportal/ncbo_cron',
  $service              = 'running',
  $repo_path            = '/srv/ncbo/repository',
  $reposymlink          = undef, #"/srv/ncbo/share/env/${ncbo_environment}/repository",
  $ruby_version         = '2.7.8',
  $logrotate_days       = 356,
  Boolean $install_java = true,
  Boolean $install_ruby = true,
  String $java_version  = 'openjdk-11-jre-headless',
) {
  require ontoportal::params
  case $facts['os']['family'] {
    'RedHat': {
      require epel
      require librdf::raptor2
    }
    'Debian': {
      ensure_packages([
        'raptor2-utils',
        'libxml2-dev',
        'libwww-perl', # required for 4s-dump to work
      ])
    }
  }

  if $install_ruby and !defined(Ontoportal::Rbenv[$ruby_version]) {
    class { 'ontoportal::rbenv':
      ruby_version => $ruby_version,
    }
  }

  file { [$app_root]:
    ensure  => directory,
    owner   => $owner,
    group   => $group ,
    mode    => '0775',
    require => Service['ncbo_cron'],
  }

  file { [$repo_path]:
     ensure => directory,
     owner  => $owner,
     group  => $group ,
     mode   => '0775',
  }

  #/tmp clean up script - Deletes files that ncbo_cron is too lazy to delete
  # we are using systemd private tmp
  file { ['/etc/cron.d/ncbo_cron_tmpclean']:
    ensure  => present,
    content => '00 05 * * * root find /tmp/systemd-private-*-ncbo_cron.service-*/tmp/* ! -name ruby-uuid -mtime +1 -delete',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  #java required for owlapi/owl validation
  if $install_java {
    class { 'java':
      package => $java_version,
    }
  }

  systemd::tmpfile { 'ncbo_cron.conf':
    ensure  => present,
    content => "d /var/run/ncbo_cron 0755 $owner $group"
  }

  systemd::unit_file { 'ncbo_cron.service':
    content => epp('ontoportal/ncbo_cron.service.epp', {
        app_root => $app_root,
        user     => $owner,
        group    => $group,
        }),
  }
  ~> service { 'ncbo_cron':
    # ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  logrotate::rule { 'ncbo_cron':
    path         => "${app_root}/logs/scheduler*.log",
    rotate       => $logrotate_days,
    minsize      => '10M',
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


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
  $app_root             = '/srv//ncbo_cron',
  $service              = 'running',
  $repo_path            = '/srv/ncbo/repository',
  $reposymlink          = undef, #"/srv/ncbo/share/env/${ncbo_environment}/repository",
  $raptor2_ver          = undef,
  $ruby_version         = '2.6.7',
  $logrotate_days       = 356,
  Boolean $install_java = true,
  Boolean $install_ruby = true,
  $java_version         = 'java-11-openjdk',
  ) {

  require librdf::raptor2
  if $install_ruby {
    class { 'ontoportal::rbenv':
      ruby_version => $ruby_version,
    }
  }

  ensure_packages([
    'mariadb-devel',
    'libxml2-devel',
    'perl-libwww-perl', # required for 4s-dump to work
  ])

  file { [ $app_root ]:
    ensure  => directory,
    owner   => $owner,
    group   => $group ,
    mode    => '0775',
    require => Service['ncbo_cron'],
  }

  if $environment == 'appliance' {
    file { [ $repo_path ]:
      ensure => directory,
      owner  => $owner,
      group  => $group ,
      mode   => '0775',
    }
  }
  else {
    file { ['/srv/ncbo/repository']:
      ensure => link,
      target => "/srv/ncbo/share/env/${environment}/repository"
    }
  }

  #required for building some of the ruby gems
  # include ncbo::builddeps

  #/tmp clean up script - Deletes files that ncbo_cron is too lazy to delete
  # we are using systemd private tmp
  file { ['/etc/cron.d/ncbo_cron_tmpclean']:
    ensure  => present,
    #content => "00 05 * * * root find /tmp -mtime +0 -type f -user ${owner} -delete > /dev/null 2>&1 ",
    #content => "00 05 * * * root find /tmp/systemd-private-*-ncbo_cron.service-*/tmp/* -mtime +1 -delete &>> /tmp/cron_tmpclean.log ",
    content => "00 05 * * * root find /tmp/systemd-private-*-ncbo_cron.service-*/tmp/* -mtime +1 -delete",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  #java required for owlapi/owl validation
  if $install_java {
    class { 'java':
      package => "${java_version}-headless"
    }
    #temporary work around
    #https://github.com/voxpupuli/puppet-alternatives/issues/71
    #this will obviously wouldn't work for other than version 11 of java
    ->exec{"make_default_${java_version}":
      command => "/usr/sbin/alternatives  --set java ${java_version}.x86_64",
      unless  => '/usr/bin/readlink /etc/alternatives/java | /usr/bin/grep -q /java-11-openjdk-11' #
  }
    #
    #  -> alternatives { 'java':
    #  path => "${java_version}.x86_64",
    #}
  }

  systemd::tmpfile {'ncbo_cron.conf':
    ensure  => present,
    content => "d /var/run/ncbo_cron 0755 ${owner} ${group}"
  }

  systemd::unit_file {'ncbo_cron.service':
    ensure  => present,
    content => epp('ontoportal/ncbo_cron.service.epp', {
      app_root => $app_root,
      user     => $owner,
      group    => $group,
      },)
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


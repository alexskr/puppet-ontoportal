# manages intrastructure services for cedar.metadatacenter.org

class ontoportal::cedar (
  String $domain = 'staging.metadatacenter.org',
  String $site = 'staging.metadatacenter.org',
  String $environment = 'staging',
  String $java_version = 'java-11-openjdk',
  String $php_version = '73',
  String $mysqlpwd_cedar_keycloak = 'changeme',
  String $mysqlpwd_cedar_log_usr = 'changeme',
  String $mysqlpwd_cedar_messaging = 'changeme',
  Boolean $manage_tls_cert = false,
  Array $sub_domains = [
    'auth',
    'artifact',
    'cedar',
    'component',
    'group',
    'repo',
    'internals',
    'resource',
    'terminology',
    'user',
    'valuerecommender',
    'schema',
    'shared',
    'submission',
    'worker',
    'messaging',
    'open',
    'openview',
    'impex',
    'cee',
    'api.cee',
    'demo.cee',
    'docs.cee',
  ],
){
  #need package nmap-ncat for cedarss 
  $cedar_bash_profile = @("CEDAR_BASH_PROFILE"/$)
  # .bash_profile

  # Get the aliases and functions
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
    fi

  # User specific environment and startup programs
  # !!!! .bash_profile is managed by Puppet
  # Please use .bash_profile.local for customization
  # or update puppet profile

  PATH=\$PATH:\$HOME/bin

  export PATH

  #Java
  export JAVA_HOME=/usr/lib/jvm/jre-11/

  # Anaconda
  export PATH=/home/cedar/anaconda3/bin:\$PATH

  #---------------------------------------------------------------------
  # CEDAR home folder
  export CEDAR_HOME=/srv/cedar/
  source \${CEDAR_HOME}/cedar-profile-native-develop.sh
  #---------------------------------------------------------------------

  export PATH=~/.npm-global/bin:\$PATH

  if [ -f ~/.bash_profile.local ]; then
    . ~/.bash_profile.local
  fi

  | CEDAR_BASH_PROFILE

  accounts::user { 'cedar':
    comment      => 'CEDAR app service account',
    uid          => '70056',
    gid          => '70056',
    shell        => '/bin/bash',
    password     => '!!',
    locked       => false,
    bash_profile_content => $cedar_bash_profile,
  }
  class { 'profile::mongodb' :
    version => '3.4.24',
    auth    => true,
  }
  include profile::maven
  #class { 'java': package => "${java_version}-devel" }

  include profile::git2

  class { 'limits':
    manage_limits_d_dir =>  false, #conflics with pam module
  }
  limits::limits {
    'cedar_file':
      user       => 'cedar',
      limit_type => 'nofile',
      both       => '10240';
    'cedar_nproc':
      user => 'cedar',
      limit_type   => 'nproc',
      both  => '4096';
    }

  file { ['/srv/neo4j','/srv/neo4j/data']:
    ensure => directory,
    owner  => 'neo4j',
    group  => 'neo4j',
    before => Service['neo4j'],
    require => Package['neo4j']  #neo4j package creates user which we need for chown
  }
  class { 'neo4j' :
    version                                => '3.5.25',
    dbms_directories_data                  => '/srv/neo4j/data',
    manage_repo                            => true,
    dbms_connector_bolt_listen_address     => ':7687',   # module sets non-standard port 9000.
    dbms_connectors_default_listen_address => '127.0.0.1',
    dbms_memory_heap_initial_size         => '2g',
    dbms_memory_heap_max_size             => '2g',
    dbms_memory_pagecache_size            => '2g', #as of 12/12/2020 graph.db is ~700M os 2G is overkill but gives room to grow.
  }
  Class['java'] -> Service['neo4j']

  # locking neo4j to version 3.5
  yum::versionlock { '0:neo4j-3.5.25-1.*':
      ensure =>  present,
  }
  yum::versionlock { '0:cypher-shell-1.1.14-1.*':
      ensure =>  present,
  }

  # 'elastic-elasticsearch', '6.4.0' module is problematic with java 11;
  # we are not using module for manaing elasticsearch for the time being.
  # https://github.com/elastic/puppet-elasticsearch/issues/1032
  # https://github.com/elastic/puppet-elasticsearch/issues/1068

  class { 'elastic_stack::repo':
      version =>  6,
  }
  ## https://github.com/metadatacenter/cedar-docs/wiki/Attic-:-Install-and-Configure-Elasticsearch-on-RHEL-6.6
  class { 'elasticsearch':
    datadir => '/srv/elasticsearch',
    config  => {
      'cluster.name' => 'elasticsearch_cedar'
      #     'script.engine.groovy.inline.search' => 'on'   # this is disabled in stage/prod so doc is not up2date
    }
  }
  mysql::db { 'cedar_keycloak':
    user     => 'cedarMySQLKeycloakUser',
    password => $mysqlpwd_cedar_keycloak,
    host     => 'localhost',
    grant    => ['ALL'],
  }
  mysql::db { 'cedar_log':
    user     => 'cedar_log_usr',
    password => $mysqlpwd_cedar_log_usr,
    host     => 'localhost',
    grant    => ['ALL'],
  }
  mysql::db { 'cedar_messaging':
    user     => 'cedar_messaging',
    password => $mysqlpwd_cedar_messaging,
    host     => 'localhost',
    grant    => ['ALL'],
  }

  if  $manage_tls_cert {
    include letsencrypt
    package { 'python2-certbot-nginx':
      ensure => installed,
    }
    $_san = $sub_domains.map |$item| { "${item}.${domain}" }
    $_domains = concat ( [$site], $_san )
    letsencrypt::certonly { $site:
        domains         => $_domains,
        plugin          => 'nginx',
        additional_args => ['--nginx-ctl /sbin/nginx'],  #certbot can't find nginx binary when running under cron. attempt to manually set it here.
        manage_cron     => true,
        require         => Package['python2-certbot-nginx'],
    }
  }
  if $environment == 'staging' {
    # PHP is used in staging env only
    #puppet-php v6.0.2  module doesn't handle remi yum repos for php 7 properly so we need a workaround
    yumrepo { "remi-php${php_version}":
      ensure     => 'present',
      descr      => "Remi\'s PHP ${php_version} RPM repository for Enterprise Linux \$releasever - \$basearch",
      enabled    => '1',
      gpgcheck   => '1',
      gpgkey     => 'https://rpms.remirepo.net/RPM-GPG-KEY-remi',
      priority   => 1,
      mirrorlist => "https://rpms.remirepo.net/enterprise/\$releasever/php${php_version}/mirror",
      before     => Class['php'],
      require    => Yumrepo['remi'],
    }

    yumrepo { "remi":
      ensure     => 'present',
      descr      => "Remi\'s RPM repository for Enterprise Linux \$releasever - \$basearch",
      enabled    => '1',
      gpgcheck   => '1',
      gpgkey     => 'https://rpms.remirepo.net/RPM-GPG-KEY-remi',
      priority   => 1,
      mirrorlist => "https://rpms.remirepo.net/enterprise/\$releasever/remi/mirror",
    }

    class { '::php':
        ensure       => latest,
        manage_repos => false,
        composer     => true,
        pear         => true,
        settings     => {
          'PHP/expose_php'          => 'Off',
          # 'PHP/max_execution_time'  => '90',
          # 'PHP/max_input_time'      => '300',
          # 'PHP/memory_limit'        => '256M',
          # 'PHP/post_max_size'       => '256M',
          # 'PHP/upload_max_filesize' => '256M',
          # 'Date/date.timezone'      => 'America/Los_Angeles',
        },

    }
  }

  # nodejs is needed for gulp
  #class { 'nodejs':}
  package { 'gulp-cli':
    ensure =>  'present',
    provider =>  'npm',
  }
  #python >3.6 is requried for some tools (cedar cron)
  ensure_packages([python3])
}

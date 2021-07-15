# a wrapper class for pupppetlabs/tomcat module.
# installs tomcat7 from epel
#
# paramteres:
# webadmin:  installs tomcat-admin-webapps package which adds
#     web based admin tools for managing tomcat.
#     it is useful for automatic deployments

class ontoportal::tomcat(
    Stdlib::Port $port                  = 8080,
    Boolean $webadmin                   = true,
    Optional[String] $java_opts         = undef,
    Boolean $manage_newrelic            = false,
    Optional[String] $java_opts_xmx     = undef,
    Integer $logrotate_days             = 14,
    Optional[String] $admin_user        = undef,
    Optional[String] $admin_user_passwd = undef,
    Boolean $manage_mysql_connector     = false,

  ){
  $catalina_base = '/usr/share/tomcat'
  require epel
  #ensure_resource

  #  user { 'tomcat':
  #  uid    => '91',
  #  gid    => '91',
  #  home   => $catalina_base,
  #  system => true,
  #  shell  => '/sbin/nologin',
  #}

  #group {'tomcat':
  #  gid => '91'
  #}
  if $webadmin {
    package { 'tomcat-admin-webapps' : ensure => installed }

    if ($admin_user_passwd == undef) and ($admin_user != undef) {
      fail( 'Tomcat admin user requires password to be set.' )
    }
    if $admin_user_passwd and  $admin_user  {
      tomcat::config::server::tomcat_users { 'admin':
        catalina_base => $catalina_base,
        element       => 'role',
      }
      -> tomcat::config::server::tomcat_users { 'manager-script':
        catalina_base => $catalina_base,
        element       => 'role',
      }
      -> tomcat::config::server::tomcat_users { $admin_user :
        catalina_base => $catalina_base,
        element       => 'user',
        element_name  => $admin_user,
        password      => $admin_user_passwd,
        roles         => ['admin', 'manager-script'],
      }
    }
  }

  # depenencies
  $packages = ['tomcat-native','log4j']
  ensure_packages([ $packages ])

  class { 'tomcat':
    catalina_home => $catalina_base,
    #   require       => Package[$packages]
  }
  tomcat::install { 'default':
    manage_user         => false,
    manage_group        => false,
    catalina_home       => $catalina_base,
    install_from_source => false,
    package_name        => 'tomcat',
  }
  tomcat::instance { 'default':
    catalina_home  => $catalina_base,
    #  install_from_source => false,
    package_name   => 'tomcat',
    use_jsvc       => false,
    use_init       => true,
    service_name   => 'tomcat',
    manage_service => true,
  }

  tomcat::config::server::connector { 'tomcat-http':
    port                  => $port,
    purge_connectors      => true,
    protocol              => 'HTTP/1.1',
    additional_attributes => {
      'redirectPort'         => '8443',
      'connectionTimeout'    => '20000',
      'disableUploadTimeout' => 'false',
      'URIEncoding'          => 'UTF-8',
      'maxThreads'           => '256',
    },
  }
  if $java_opts_xmx {
    tomcat::setenv::entry { 'XMX':
      config_file => '/etc/tomcat/conf.d/java_opts.conf',
      addto       => 'JAVA_OPTS',
      value       => "-Xmx${java_opts_xmx}",
      quote_char  => "'",
    }
  }
  if $manage_newrelic {
    tomcat::setenv::entry { 'NEWRELIC':
      config_file => '/etc/tomcat/conf.d/java_opts.conf',
      addto       => 'JAVA_OPTS',
      value       => '-javaagent:/opt/newrelic/newrelic.jar',
      quote_char  => "'",
    }
  }
  tomcat::setenv::entry { 'STANDARD':
    config_file => '/etc/tomcat/conf.d/java_opts.conf',
    addto       => 'JAVA_OPTS',
    value       => "-Djava.awt.headless=true -Djava.net.preferIPv4Stack=true ${java_opts}",
    quote_char  => "'",
  }
  if $manage_mysql_connector {
    class { 'mysql_java_connector':
      links   => [ '/usr/share/tomcat/lib' ],
      require => Class[ 'tomcat' ]
    }
  }
  logrotate::rule { 'tomcat':
    path         => '/var/log/tomcat/catalina.out',
    rotate       => $logrotate_days,
    size         => '10M',
    dateext      => true,
    compress     => true,
    copytruncate => true,
    missingok    => true,
    su_user      => 'tomcat',
    su_group     => 'tomcat',
  }
}

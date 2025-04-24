
# a wrapper class for pupppetlabs/tomcat module.
# installs tomcat9 from source
class ontoportal::tomcat(
  String $version                     = '9.0.104',
  Stdlib::Port $port                  = 8080,
  Stdlib::HTTPUrl $source_url = "https://archive.apache.org/dist/tomcat/tomcat-9/v${version}/bin/apache-tomcat-${version}.tar.gz",
  Boolean $webadmin                   = false,
  Optional[String] $java_opts         = undef,
  Boolean $manage_newrelic            = false,
  Optional[String] $java_opts_xmx     = undef,
  Integer $logrotate_days             = 14,
  Optional[String] $admin_user        = undef,
  Optional[String] $admin_user_passwd = undef,
  $catalina_base                      = '/srv/tomcat',
  $catalina_home                      = "/opt/tomcat-${version}",
  Boolean $suppress_catalina_out      = false,
) {
  file { ['/var/log/tomcat', '/var/lib/tomcat', '/var/lib/tomcat/webapps']:
    ensure => directory,
    owner  => 'tomcat',
    group  => 'tomcat',
    mode   => '0770',
  }

  if $webadmin {
    if ($admin_user_passwd == undef) and ($admin_user != undef) {
      fail( 'Tomcat admin user requires password to be set.' )
    }
    if $admin_user_passwd and $admin_user {
      tomcat::config::server::tomcat_users { 'admin-script':
        catalina_base => $catalina_base,
        element       => 'role',
        require       => Class['tomcat']
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
        roles         => ['admin-script', 'manager-script'],
      }
    }
  }

  $_systemd_unit_file_content = @("EOT")
    [Unit]
    Description=Apache Tomcat Web Application Container
    After=syslog.target network.target

    [Service]
    Type=forking
    User=tomcat
    Group=tomcat
    Environment=CATALINA_PID=${catalina_home}/temp/tomcat.pid
    Environment=CATALINA_HOME=${$catalina_home}
    Environment=CATALINA_BASE=${catalina_base}
    User=tomcat

    ExecStart=${catalina_home}/bin/startup.sh
    ExecStop=${catalina_home}/bin/shutdown.sh

    [Install]
    WantedBy=multi-user.target
    | EOT

  class { 'tomcat': }
  tomcat::install { $catalina_home:
    source_url => $source_url,
  }
  tomcat::instance { 'default':
    dir_list       => ['bin','conf','lib','temp','webapps','work'], #logs will be symlinked to /var/log/tomcat
    catalina_home  => $catalina_home,
    catalina_base  => $catalina_base,
    manage_service => false,
  }
  -> file { "${catalina_base}/logs":
    ensure  => link,
    force   => true,  #overwrite existing directory added by install
    target  => '/var/log/tomcat',
    require => File['/var/log/tomcat'],
  }
  -> systemd::unit_file { 'tomcat.service':
    content => $_systemd_unit_file_content,
  }
  ~> service { 'tomcat':
    enable  => true,
    ensure  => 'running',
    require => Class['tomcat'],
  }

  tomcat::config::server::connector { 'tomcat-http':
    catalina_base         => $catalina_base,
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
      #       catalina_base  => $catalina_base,
      addto      => 'JAVA_OPTS',
      value      => "-Xmx${java_opts_xmx}",
      quote_char => "'",
    }
  }
  if $manage_newrelic {
    tomcat::setenv::entry { 'NEWRELIC':
      addto      => 'JAVA_OPTS',
      value      => '-javaagent:/opt/newrelic/newrelic.jar',
      quote_char => "'",
    }
  }
  tomcat::setenv::entry { 'STANDARD':
    catalina_home => $catalina_home,
    addto         => 'JAVA_OPTS',
    value         => "-Djava.awt.headless=true -Djava.net.preferIPv4Stack=true ${java_opts}",
    quote_char    => "'",
  }
  # https://stackoverflow.com/questions/34648592/how-to-stop-application-logs-from-logging-into-catalina-out-in-tomcat
  if $suppress_catalina_out {
    tomcat::setenv::entry { 'CATALINA_OUT':
      catalina_home => $catalina_home,
      value         => '/dev/null',
      doexport      => false,
    }
  }

  logrotate::rule { 'tomcat':
    path         => "${catalina_base}/logs/catalina.out",
    rotate       => $logrotate_days,
    size         => '10M',
    dateext      => true,
    compress     => true,
    copytruncate => true,
    missingok    => true,
    su           => true,
    su_user      => 'tomcat',
    su_group     => 'tomcat',
    rotate_every => 'day',
  }
}

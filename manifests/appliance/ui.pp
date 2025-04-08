########################################################################
#@memcached_max_memory = max memory for memcached
#  can be integer representing max memory im MB, i.e 512, or persentage '10%' of available memory

# this is more of a role than a profile.
class ontoportal::appliance::ui (
  String               $ui_domain_name,
  Stdlib::Absolutepath $app_root_dir       = '/opt/ontoportal',
  Stdlib::Absolutepath $log_dir            = '/var/log/ontoportal',

  String $admin_user         = 'ontoportal-admin',
  String $ui_user            = 'ontoportal-ui',
  String $shared_group       = 'ontoportal',
  String $ruby_version       = '3.1.6',

  String  $group              = 'ontoportal-ui',
  Boolean  $manage_firewall   = true,
  Boolean  $manage_letsencrypt = false,
  Boolean              $enable_https = true,
  Optional[Integer]    $puma_workers   = undef,
  String               $memcached_max_memory = '512',
) {
  if $manage_firewall {
    include ontoportal::firewall::http
  }
  $owner = $admin_user
  class { 'ontoportal::bioportal_web_ui':
    environment        => 'appliance',
    ruby_version       => $ruby_version,
    service_account    => $ui_user,
    owner              => $owner,
    group              => $group,
    manage_letsencrypt => $manage_letsencrypt,
    logrotate_nginx    => 7,
    logrotate_ui       => 7,
    app_dir            => "${app_root_dir}/bioportal_web_ui",
    domain             => $ui_domain_name,
    slices             => [],
    manage_ruby        => true,
    puma_workers       => $puma_workers,
  }

  # proxy for BioMixer
  nginx::resource::location { 'biomixer':
    ensure           => present,
    server           => 'ontoportal_web_ui',
    ssl              => $enable_https,
    location         => '/biomixer',
    proxy            => 'http://127.0.0.1:8082',
    proxy_set_header => [
      'Host $host',
      'X-Real-IP $remote_addr',
      'X-Forwarded-For $proxy_add_x_forwarded_for',
    ],
  }

  class { 'mysql::server':
    remove_default_accounts => true,
    override_options        => {
      'mysqld'                           => {
        'innodb_buffer_pool_size'        => '64M',
        'innodb_flush_log_at_trx_commit' => '0',
        'innodb_file_per_table'          => '',
        'innodb_flush_method'            => 'O_DIRECT',
        'character-set-server'           => 'utf8mb4',
      },
    },
  }

  class { 'mysql::client': }
  mysql::db { 'bioportal_web_ui_appliance':
    user     => 'bp_ui_appliance',
    password => '*EBE8A8D53522BAC12B99F606FC3C3757742DE6FB',
    host     => 'localhost',
    grant    => ['ALL'],
    charset  => 'utf8mb4',
    collate  => 'utf8mb4_unicode_ci',
  }

  class { 'memcached':
    max_memory    => $memcached_max_memory,
    max_item_size => '5M',
  }

  #FIXME
  # add placeholder files with proper permissions for deployment
  file { '/srv/tomcat/webapps/biomixer.war':
    replace => false,
    content => 'placeholder',
    mode    => '0644',
    owner   => $owner,
    require => Class[ontoportal::tomcat],
  }
}

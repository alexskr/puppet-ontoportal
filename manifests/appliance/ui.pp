########################################################################

# this is more of a role than a profile.
class ontoportal::appliance::ui (
  $owner = $ontoportal::appliance::owner,
  $group = $ontoportal::appliance::group,
  $appliance_version = $ontoportal::appliance::appliance_version,
  $ruby_version = $ontoportal::appliance::ruby_version,
  $data_dir = $ontoportal::appliance::data_dir,
  $app_root_dir  = $ontoportal::appliance::app_root_dir,
  $ui_domain_name = $ontoportal::appliance::ui_domain_name,
  $api_domain_name = $ontoportal::appliance::api_domain_name,
) {
  include ontoportal::firewall::http

  # Create Directories (including parent directories)
  # file { [$app_root_dir,
  #   ]:
  #     ensure => directory,
  #     owner  => $owner,
  #     group  => $group,
  #     mode   => '0775',
  #}
  # chaining api and UI,  sometimes passenger yum repo confuses nginx installation.
  Class['epel'] -> Class['ontoportal::bioportal_web_ui']

  class { 'ontoportal::bioportal_web_ui':
    environment       => 'appliance',
    ruby_version      => $ruby_version,
    owner             => $owner,
    group             => $group,
    enable_mod_status => false,
    logrotate_httpd   => 7,
    logrotate_rails   => 7,
    railsdir          => "${app_root_dir}/bioportal_web_ui",
    domain            => $ui_domain_name,
    slices            => [],
    enable_ssl        => true,
    # self-generated certificats
    ssl_cert          => '/etc/pki/tls/certs/localhost.crt',
    ssl_key           => '/etc/pki/tls/private/localhost.key',
    ssl_chain         => '/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt',
    install_ruby      => false,
    require           => Class['ontoportal::rbenv'],
  }

  # mod_proxy is needed for reverse proxy of biomixer and annotator plus proxy
  include apache::mod::proxy
  include apache::mod::proxy_http

  ##mysql setup
  class { 'mysql::server':
    remove_default_accounts => true,
    override_options        => {
      'mysqld'                           => {
        'innodb_buffer_pool_size'        => '64M',
        'innodb_flush_log_at_trx_commit' => '0',
        'innodb_file_per_table'          => '',
        'innodb_flush_method'            => 'O_DIRECT',
        'character-set-server'           => 'utf8',
      },
    },
  }

  class { 'mysql::client': }
  mysql::db { 'bioportal_web_ui_appliance':
    user     => 'bp_ui_appliance',
    password => '*EBE8A8D53522BAC12B99F606FC3C3757742DE6FB',
    host     => 'localhost',
    grant    => ['ALL'],
  }

  class { 'memcached':
    max_memory    => '512m',
    max_item_size => '5M',
  }
  # add placeholder files with proper permissions for deployment
  file { '/srv/tomcat/webapps/biomixer.war':
    replace => 'no',
    content => 'placeholder',
    mode    => '0644',
    owner   => $owner,
    require => Class[ontoportal::tomcat],
  }
}

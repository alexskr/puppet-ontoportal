class ontoportal::appliance::api (
  Stdlib::Absolutepath $app_root_dir        = '/opt/ontoportal',
  Stdlib::Absolutepath $data_dir            = '/srv/ontoportal',
  String               $api_domain_name     = 'api.example.org',
  String               $owner               = 'ontoportal-admin',
  String               $group               = 'ontoportal-admin', #FIXME do we need this?
  String               $admin_user          = 'ontoportal-admin',
  String               $backend_account     = 'ontoportal-backend',
  String               $data_group          = $admin_user,
  String               $ruby_version        = '3.1.6',
  String               $appliance_version   = '4.0',
  String               $goo_cache_maxmemory = '512M',
  String               $http_cache_maxmemory = '512M',
  Boolean              $manage_firewall     = true,
  Boolean              $manage_letsencrypt  = false,
  Boolean              $enable_https        = true,
  Optional[Integer]    $api_port            = 8080,
  Optional[Integer]    $api_port_https      = 8443,
  Boolean              $manage_service_account = true,
  Enum['4store', 'agraph', 'external'] $triple_store = 'agraph',
) {
  if $manage_firewall {
    include ontoportal::firewall::api
  }

  User <| title == $admin_user |> { groups +> 'tomcat' } # FIXME might not need to do this?
  class { 'ontoportal::ncbo_cron':
    environment => 'appliance',
    owner       => $backend_account,
    group       => $data_group,
    manage_ruby => false,
    manage_java => false,
    app_path    => "${app_root_dir}/ncbo_cron",
    repo_path   => "${data_dir}/repository",
  }

  class { 'ontoportal::ontologies_api':
    environment         => 'appliance',
    port                => $api_port,
    port_https          => $api_port_https,
    domain              => $api_domain_name,
    admin_user          => $admin_user,
    ruby_version        => $ruby_version,
    service_account     => $backend_account,
    data_group          => $data_group,
    manage_letsencrypt  => $manage_letsencrypt,
    enable_nginx_status => false, #not requried for appliance
    manage_nginx_repo   => false,
    manage_firewall     => false,
    manage_ruby         => true,
    manage_java         => false,
    app_dir             => "${app_root_dir}/ontologies_api",
  }

  class { 'ontoportal::redis::goo_cache':
    maxmemory       => $goo_cache_maxmemory,
    manage_firewall => false,
    manage_newrelic => false,
  }

  class { 'ontoportal::redis::persistent':
    manage_firewall => false,
    workdir         => "${data_dir}/redis_persistent",
    manage_newrelic => false,
    # require         => File[$data_dir],
  }

  class { 'ontoportal::redis::http_cache':
    maxmemory       => $http_cache_maxmemory,
    manage_firewall => false,
    manage_newrelic => false,
  }

  class { 'ontoportal::solr':
    manage_java     => false,
    deployeruser    => $admin_user,
    deployergroup   => $admin_user,
    manage_firewall => false,
    solr_heap       => '512M',
    var_dir         => "${data_dir}/solr",
  }

  case $triple_store {
    '4store': {
      class { 'fourstore':
        data_dir => "${data_dir}/4store",
        port     => 8081,
        fsnodes  => '127.0.0.1',
      }
      fourstore::kb { 'ontologies_api': segments => 4 }
    }
    'agraph': {
      include ontoportal::agraph
    }
    'external': {
      notice("Skipping triple store setup; it's managed externally.")
    }
    default: {
      fail("Unexpected triple store option: ${triple_store}")
    }
  }

  class { 'mgrep':
    mgrep_enable => true,
    group        => $backend_account,
    dict_path    => "${data_dir}/mgrep/dictionary/dictionary.txt",
  }

  include mgrep::dictrefresh

  # annotator plus proxy reverse proxy
  nginx::resource::location { '/annotatorplus/':
    ensure => present,
    ssl    => true,
    server => 'ontologies_api',
    proxy  => 'http://localhost:8082/annotatorplus/',
  }

  # add placeholder files with proper permissions for deployment
  file { '/srv/tomcat/webapps/annotatorplus.war':
    replace => 'no',
    content => 'placeholder',
    mode    => '0644',
    owner   => $admin_user,
    require => Class[ontoportal::tomcat],
  }
}

class ontoportal::appliance::api (
  Stdlib::Absolutepath $app_root_dir,
  Stdlib::Absolutepath $data_dir,
  Stdlib::Absolutepath $log_root_dir,
  String               $api_domain_name,
  String               $owner,
  String               $group, #FIXME do we need this?
  String               $admin_user,
  String               $backend_user,
  String               $shared_group,
  String               $ruby_version,
  String               $appliance_version,
  String               $goo_cache_maxmemory = '512M',
  String               $http_cache_maxmemory = '512M',
  Boolean              $manage_firewall,
  Boolean              $manage_letsencrypt,
  Boolean              $enable_https,
  Integer              $api_port,
  Integer              $api_port_https,
  Enum['4store', 'agraph', 'external'] $triple_store,
) {
  if $manage_firewall {
    include ontoportal::firewall::api
  }

  # just in case both API and UI are running on the same node
  # this needs to refactored
  $catch_all = ($api_port == 80 and $api_port_https == 443 ) ? {
    true =>  undef,
    false =>  'default_server',
  }

  User <| title == $admin_user |> { groups +> 'tomcat' } # FIXME might not need to do this?

  class { 'ontoportal::ncbo_cron':
    service_account => $backend_user,
    admin_user      => $admin_user,
    group           => $shared_group,
    manage_ruby     => false,
    manage_java     => false,
    app_dir         => "${app_root_dir}/ncbo_cron",
    repo_dir        => "${data_dir}/repository",
    log_dir         => "${log_root_dir}/ncbo_cron",
  }

  class { 'ontoportal::profile::api':
    environment     => 'appliance',
    admin_user      => $admin_user,
    service_account => $backend_user,
    ruby_version    => $ruby_version,
    data_group      => $shared_group,
    manage_ruby     => true,
    manage_java     => false,
    app_root_dir    => $app_root_dir,
    log_dir         => "${log_root_dir}/ontologies_api",
  }

  class { 'ontoportal::nginx::proxy_api':
    environment        => 'appliance',
    port               => $api_port,
    port_https         => $api_port_https,
    domain             => $api_domain_name,
    manage_letsencrypt => $manage_letsencrypt,
    manage_firewall    => false,
    catch_all          => $catch_all,
    log_dir            => "${log_root_dir}/ontologies_api",
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
    group        => $shared_group,
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

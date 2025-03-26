########################################################################

class ontoportal::appliance::api (
  Boolean $manage_firewall = $ontoportal::appliance::manage_firewall,
  Boolean $manage_letsencrypt = $ontoportal::appliance::manage_letsencrypt,
  $goo_cache_maxmemory = $ontoportal::appliance::goo_cache_maxmemory,
  $http_cache_maxmemory = $ontoportal::appliance::http_cache_maxmemory,
  $api_port = $ontoportal::appliance::api_port,
  $api_port_https = $ontoportal::appliance::api_port_https,
  $owner = $ontoportal::appliance::owner,
  $group = $ontoportal::appliance::group,
  $appliance_version = $ontoportal::appliance::appliance_version,
  $ruby_version = $ontoportal::appliance::api_ruby_version,
  $data_dir = $ontoportal::appliance::data_dir,
  $app_root_dir  = $ontoportal::appliance::app_root_dir,
  $api_domain_name = $ontoportal::appliance::api_domain_name,
  Boolean $enable_4store = false,
) {
  if $manage_firewall {
    include ontoportal::firewall::api
  }

  User <| title == ontoportal |> { groups +> 'tomcat' }

  # Create Directories (including parent directories)
  file { ['/srv/ontoportal', $data_dir,
      "${data_dir}/reports", "${data_dir}/mgrep",
      "${data_dir}/mgrep/dictionary/",
    ]:
      ensure => directory,
      owner  => $owner,
      group  => $group,
      mode   => '0775',
  }

  class { 'ontoportal::ncbo_cron':
    environment  => 'appliance',
    owner        => $owner,
    group        => $group,
    install_ruby => false,
    app_path     => "${app_root_dir}/ncbo_cron",
    repo_path    => "${data_dir}/repository",
  }

  class { 'ontoportal::ontologies_api':
    environment         => 'appliance',
    port                => $api_port,
    port_https          => $api_port_https,
    domain              => $api_domain_name,
    ruby_version        => $ruby_version,
    owner               => $owner,
    group               => $group,
    manage_letsencrypt  => $manage_letsencrypt,
    enable_nginx_status => false, #not requried for appliance
    manage_nginx_repo   => false,
    manage_firewall     => false,
    install_ruby        => true,
    install_java        => false,
    app_root            => "${app_root_dir}/ontologies_api",
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
    require         => File[$data_dir],
  }
  class { 'ontoportal::redis::http_cache':
    maxmemory       => $http_cache_maxmemory,
    manage_firewall => false,
    manage_newrelic => false,
  }
  class { 'ontoportal::solr':
    manage_java     => false,
    deployeruser    => $owner,
    deployergroup   => $owner,
    manage_firewall => false,
    solr_heap       => '512M',
    var_dir         => "${data_dir}/solr",
  }

  if $enable_4store  {
    class { 'fourstore':
      data_dir => "${data_dir}/4store",
      port     => 8081,
      fsnodes  => '127.0.0.1',
    }
    fourstore::kb { 'ontologies_api': segments => 4 }
  }

  class { 'ontoportal::agraph':
  }

  class { 'mgrep':
    mgrep_enable => true,
    group        => $group,
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
    owner   => $owner,
    require => Class[ontoportal::tomcat],
  }
}

########################################################################

# this is more of a role than a profile.
class ontoportal::appliance::api (
  $api_port = $ontoportal::appliance::api_port,
  $owner = $ontoportal::appliance::owner,
  $group = $ontoportal::appliance::group,
  $appliance_version = $ontoportal::appliance::appliance_version,
  $ruby_version = $ontoportal::appliance::ruby_version,
  $data_dir = $ontoportal::appliance::data_dir,
  $app_root_dir  = $ontoportal::appliance::app_root_dir,
  $ui_domain_name = $ontoportal::appliance::ui_domain_name,
  $api_domain_name = $ontoportal::appliance::api_domain_nam,
) {
  include ontoportal::firewall::p8080

  # Create Directories (including parent directories)
  file { [$data_dir,
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
    app_root     => "${app_root_dir}/ncbo_cron",
    repo_path    => "${data_dir}/repository",
    require      => Class['epel'],
  }

  #chaining classes so that java alternatives is set properly after 1 run.
  # chaining api and UI,  sometimes passenger yum repo confuses nginx installation.
  Class['epel'] -> Class['ontoportal::ontologies_api']

  class { 'ontoportal::ontologies_api':
    environment         => 'appliance',
    port                => $api_port,
    domain              => $api_domain_name,
    owner               => 'ontoportal',
    group               => 'ontoportal',
    enable_ssl          => false, #not nessesary for appliance
    enable_nginx_status => false, #not requried for appliance
    manage_nginx_repo   => false,
    install_ruby        => false,
    install_java        => false,
    app_root            => "${app_root_dir}/ontologies_api",
    require             => Class['epel'],
  }

  class { 'ontoportal::redis_goo_cache':
    maxmemory       => '512M',
    manage_firewall => false,
    manage_newrelic => false,
  }
  class { 'ontoportal::redis_persistent':
    manage_firewall => false,
    workdir         => "${data_dir}/redis_persistent",
    manage_newrelic => false,
  }
  class { 'ontoportal::redis_http_cache':
    maxmemory       => '512M',
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

  class { 'fourstore':
    data_dir => "${data_dir}/4store",
    port     => 8081,
    fsnodes  => '127.0.0.1',
  }
  fourstore::kb { 'ontologies_api': segments => 4 }

  class { 'mgrep':
    mgrep_enable => true,
    group        => $group,
    dict_path    => "${data_dir}/mgrep/dictionary/dictionary.txt",
  }
  include mgrep::dictrefresh

  # annotator plus proxy reverse proxy
  nginx::resource::location { '/annotatorplus/':
    ensure => present,
    # ssl   => false,
    server => 'ontologies_api',
    proxy  => 'http://localhost:8082/annotatorplus/',
  }

  #class { 'ontoportal::tomcat':
  #  port     => 8082,
  #  webadmin => false,
  #}

  # add placeholder files with proper permissions for deployment
  file { '/usr/share/tomcat/webapps/annotatorplus.war':
    replace => 'no',
    content => 'placeholder',
    mode    => '0644',
    owner   => $owner,
  }
}

#
# Class: ncbo::profile::solr
#
# Description: This class manages standalone solr server
#
# To keep things simple it is hardcoded to handle only ncbo solr
# we install 4 solr cores
#
# Parameters:
#
# Actions:
#
#
# Works with 8.2.0 +

class ontoportal::solr (
  String $version                  = '8.11.3',
  String $solr_host                = '0.0.0.0',
  Stdlib::Absolutepath $var_dir    = '/srv/ontoportal/data/solr',
  Stdlib::Absolutepath $data_dir   = "${var_dir}/data",
  Stdlib::Absolutepath $config_dir = "${var_dir}/config",
  String $owner                    = 'solr',
  String $group                    = 'solr',
  String $deployeruser             = 'ontoportal',
  String $deployergroup            = 'ontoportal',
  Optional[String] $solr_heap      = undef,
  Boolean $newrelic                = false,
  String $newrelic_agent_version   = '7.11.1',
  Boolean $manage_firewall         = false,
  Boolean $manage_java             = true,
  String $java_package             = 'openjdk-11-jdk-headless',
  $fwsrc                           = [],
) {
  if $manage_java {
    Class { 'java':
      package => $java_package
    }
  }

  if $solr_heap == undef {
    $_solr_heap =  inline_template('<%= Integer(@memorysize_mb.to_i * 0.60)%>M')
  } else {
    $_solr_heap = $solr_heap
  }
  if $manage_firewall {
    firewall_multi { '33 allow solr on port 8983':
      source => $fwsrc,
      dport  => 8983,
      proto  => tcp,
      jump   => accept,
    }
  }

  # JDK openjdk_11.0.8+ is required
  # OpenJDK 11 problem described at https://issues.apache.org/jira/browse/SOLR-13606

  if $newrelic == true {
    $_solr_environment = [ 'SOLR_OPTS="${SOLR_OPTS} -javaagent:/opt/newrelic/newrelic.jar"'] # lint:ignore:single_quote_string_with_variables
    class { 'newrelic::agent::java':
      package_version           => $newrelic_agent_version,
      newrelic_application_name => 'BioPortal Solr',
    }
  } else {
    $_solr_environment = 'SOLR_OPTS="${SOLR_OPTS}"' # lint:ignore:single_quote_string_with_variables
  }

  user { 'solr':
    ensure     => 'present',
    comment    => 'solr',
    system     => true,
    managehome => true,
    home       => $var_dir,
    password   => '!!',
    shell      => '/bin/bash',
    before     => Class['solr'],
  }

  class { 'solr':
    #  url              => "https://dlcdn.apache.org/lucene/solr",
    version          => $version,
    solr_host        => $solr_host,
    solr_heap        => $_solr_heap,
    solr_home        => $data_dir,
    manage_user      => false,
    manage_java      => false,
    java_home        => '/usr/lib/jvm/java-11-openjdk-amd64',
    var_dir          => $var_dir,
    solr_environment => [$_solr_environment],
  }

  $core_dirs = [
    "${data_dir}/prop_search_core1/", "${data_dir}/prop_search_core1/data",
    "${data_dir}/prop_search_core2/", "${data_dir}/prop_search_core2/data",
    "${data_dir}/term_search_core1/", "${data_dir}/term_search_core1/data",
    "${data_dir}/term_search_core2/", "${data_dir}/term_search_core2/data",
  ]
  $core_prop_files = [
    "${data_dir}/term_search_core1/core.properties",
    "${data_dir}/term_search_core2/core.properties",
    "${data_dir}/prop_search_core1/core.properties",
    "${data_dir}/prop_search_core2/core.properties",
  ]

  # file { $data_dir:
  #   ensure    => directory,
  #   owner     => $owner,
  #   group     => $group,
  #   mode      => '0755',
  #   require   => File[$var_dir],
  #   #require  => Class['solr'],
  #   subscribe => Class['solr'],
  # }
  file { $config_dir:
    ensure  => directory,
    owner   => $deployeruser,
    group   => $deployergroup,
    mode    => '0755',
    before  => Class['solr'],
    require => User['solr'],
  }
  -> file { ["${config_dir}/property_search", "${config_dir}/term_search"]:
    ensure  => directory,
    owner   => $deployeruser,
    group   => $deployergroup,
    mode    => '0644',
    recurse => true,
  }
  -> file { $core_dirs:
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0755',
  }
  -> file {
    "${data_dir}/prop_search_core1/conf":
      ensure => symlink,
      target => "${config_dir}/property_search";
    "${data_dir}/prop_search_core2/conf":
      ensure => symlink,
      target => "${config_dir}/property_search";
  #term search cores
    "${data_dir}/term_search_core1/conf":
      ensure => symlink,
      target => "${config_dir}/term_search";
    "${data_dir}/term_search_core2/conf":
      ensure => symlink,
      target => "${config_dir}/term_search";
  }
  -> file { $core_prop_files:
    owner => $owner,
    group => $group,
  }

  file { "${data_dir}/solr.xml":
    owner   => $deployeruser,
    group   => $deployergroup,
    mode    => '0644',
    replace => false,
    content => '<solr> </solr>',
  }

  exec { 'initial config property_search':
    cwd     => $config_dir,
    command => "/bin/cp -avr /opt/solr/server/solr/configsets/_default/conf/* ${config_dir}/property_search && \
                /bin/chown -R ${deployeruser}:${deployergroup} ${config_dir}/property_search",
    unless  => "/usr/bin/test -f ${config_dir}/property_search/managed-schema",
    timeout => 600,
    require => [File[$config_dir], Class['solr']],
  }
  exec { 'initial config term_search':
    cwd     => $config_dir,
    command => "/bin/cp -avr /opt/solr/server/solr/configsets/_default/conf/* ${config_dir}/term_search && \
                /bin/chown -R ${deployeruser}:${deployergroup} ${config_dir}/term_search",
    unless  => "/usr/bin/test -f ${config_dir}/term_search/managed-schema",
    timeout => 600,
    require => [ File[$config_dir], Class['solr'],]
  }

  #v8.2 has global maxboolClauses setting which sets global max. We have to set it here in addition to solrconfig.xml
  augeas { 'solr_max_boolean_classes.xml':
    incl    => "${data_dir}/solr.xml",
    lens    => 'Xml.lns',
    context => "/files/${data_dir}/solr.xml/solr",
    changes => ["set int/#text '\${solr.max.booleanClauses:500000}'",],
    require => File["${data_dir}/solr.xml"],
  }
}

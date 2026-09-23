#
# Class: ontoportal::solr
#
# Description: single-node SolrCloud using Solr's embedded ZooKeeper.
#
# goo creates the term/property search collections and their aliases
# through the Collections API, so no cores or configsets are laid down here.
#
# solr_host is what Solr registers in the cluster state; it stays 'localhost'
# so the collections survive a hostname change, e.g. an image booted as a new VM.
#
# Requires markt-solr and Solr 9.

class ontoportal::solr (
  String $version                  = '9.10.1',
  Stdlib::Host $jetty_host         = '127.0.0.1',
  Stdlib::Host $solr_host          = 'localhost',
  Stdlib::Absolutepath $var_dir    = '/srv/ontoportal/data/solr',
  Optional[String] $solr_heap      = undef,
  Integer $max_boolean_clauses     = 500000,
  Boolean $newrelic                = false,
  String $newrelic_agent_version   = '7.11.1',
  Boolean $manage_firewall         = false,
  Boolean $manage_java             = true,
  String $java_package             = 'openjdk-17-jre-headless',
  Stdlib::Absolutepath $java_home  = "/usr/lib/jvm/java-17-openjdk-${facts['os']['architecture']}",
  $fwsrc                           = [],
) {
  # a package rather than the java class, so it can sit next to the system default JRE
  if $manage_java {
    stdlib::ensure_packages([$java_package])
    Package[$java_package] -> Class['solr']
  }

  if $solr_heap == undef {
    $_solr_heap = "${Integer($facts['memory']['system']['total_bytes'] * 0.6 / 1024 / 1024)}M"
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

  if $newrelic {
    class { 'newrelic::agent::java':
      package_version           => $newrelic_agent_version,
      newrelic_application_name => 'BioPortal Solr',
    }
    $_newrelic_opts = ['-javaagent:/opt/newrelic/newrelic.jar']
  } else {
    $_newrelic_opts = []
  }

  # zk_ensemble is left unset so Solr starts its embedded ZooKeeper
  class { 'solr':
    version    => $version,
    upgrade    => true,
    cloud      => true,
    jetty_host => $jetty_host,
    solr_host  => $solr_host,
    java_home  => $java_home,
    java_mem   => "-Xms${_solr_heap} -Xmx${_solr_heap}",
    var_dir    => $var_dir,
    solr_opts  => ["-Dsolr.max.booleanClauses=${max_boolean_clauses}"] + $_newrelic_opts,
  }
}

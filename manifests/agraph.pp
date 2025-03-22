#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class ontoportal::agraph(
  String $version             = '8.3.1',
  String $package_name        = "agraph-${version}-linuxamd64.64.tar.gz",
  Stdlib::HTTPUrl $source_url = "https://franz.com/ftp/pri/acl/ag/ag${version}/linuxamd64.64/${package_name}",
  Stdlib::Port $port          = 10035,
  String $ensure              = present,
  $service_ensure             = 'running',
  Boolean $manage_fw          = false,
  Boolean $optimize_kernel    = false,
  Optional[String] $license   = undef,
  Stdlib::Absolutepath $data_dir    = '/srv/ontoportal/data/agraph',
  Stdlib::Absolutepath $app_path    = "/opt/agraph-${version}",
  Stdlib::Absolutepath $config_path = "/etc/agraph/agraph.cfg",
  Optional[Array] $fwsrc = undef,
  Optional[Array] $mm_nodes = [], #multi master replication nodes
) {

  if ($facts['os']['family'] != 'Debian') {
      fail ('this module supports only Debian/Ubuntu')
  }

  archive { "/opt/staging/${package_name}":
    source       => $source_url,
    extract_path => '/opt/staging',
    extract      => true,
    creates      => "/opt/staging/agraph-${version}",
    cleanup      => true,
    require      => [
      User['agraph'],
      File['/etc/agraph/agraph.cfg'],
      File["${data_dir}/settings/user/super"]
    ]
  }

  exec { "install_agraph_${version}":
    command     => "/opt/staging/agraph-${version}/install-agraph --no-configure /opt/agraph-${version}",
    cwd         => "/opt/staging/agraph-${version}",
    path        => ['/bin', '/usr/bin'], # Add directories to $PATH as needed
    refreshonly => true, # Only run on change
    require     => Archive["/opt/staging/${package_name}"],
    subscribe   => Archive["/opt/staging/${package_name}"], # Re-run if the archive is updated
  }

  file { '/opt/agraph':
    ensure => simlink,
    target  => $app_path,
  }

  systemd::unit_file { 'agraph.service':
    content => epp ('ontoportal/agraph.service.epp', {
      'app_path'     => $app_path,
      'config_path'  => $config_path,
    }),
  }
  ~> service { "agraph.service":
    ensure     => $service_ensure,
    enable     =>  true,
    hasstatus  => true,
    hasrestart =>  true,
    require    => Exec["install_agraph_${version}"],
  }

  if $optimize_kernel {
  sysctl { 'vm.overcommit_memory': value => '1' }
    kernel_parameter { 'transparent_hugepage':
      ensure  => present,
      value => 'never',
    }
  }

  if $manage_fw {
    firewall_multi { "33 allow agraph on port $port":
      source => $fwsrc + $mm_nodes,
      dport  => $port,
      proto  => tcp,
      jump   => accept,
    }
    firewall_multi { "34 allow agraph replication on port $port":
      source => $mm_nodes,
      dport  => '13000:13020',
      proto  => tcp,
      jump   => accept,
    }
  }

  group { 'agraph':
    gid => '808',
  }

  # set UID for agraph user in case we do backups to NFS storage
  user { 'agraph':
    ensure  => 'present',
    comment => 'AllegroGraph',
    system  => true,
    uid     => '808',
    gid     => '808',
    home    => '/home/agraph',
    shell   => '/bin/bash',
  }

  file { '/etc/agraph':
    ensure => directory,
    mode   => '0755',
    owner  => root,
    group  => root,
  }
  -> file { ['/var/run/agraph', '/var/log/agraph']:
    ensure => directory,
    mode   => '0755',
    owner  => 'agraph',
    group  => 'agraph',
  }

  file { '/etc/agraph/agraph.cfg':
    ensure  => present,
    mode    => '0644',
    owner   => root,
    group   => root,
    content =>  epp ('ontoportal/agraph.config.epp', {
      'data_dir' => $data_dir,
      'license'  => $license,
    }),
  }

  file { [$data_dir, "${data_dir}/settings", "${data_dir}/settings/user"]:
    ensure  => directory,
    mode    => '0750',
    owner   => agraph,
    group   => agraph,
    require => User[agraph],
  }

  file { "${data_dir}/settings/user/super":
    mode    => '0600',
    owner   => agraph,
    replace => false, # create file but don't update it
    group   => agraph,
    content => '(#x3b74c0e3a9d8517db3e3d3009f18580507438674 (:super) nil nil nil)\n'
  }

}

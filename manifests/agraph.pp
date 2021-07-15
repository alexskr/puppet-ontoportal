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
  String $version                = '7.0.4',
  String $package_name           = "agraph-${version}-1",
  Stdlib::HTTPUrl $source_url    = "https://franz.com/ftp/pri/acl/ag/ag${version}/linuxamd64.64/${package_name}.x86_64.rpm",
  Stdlib::Port $port             = 10035,
  String $ensure                 = present,
  Boolean $service_ensure        = true,
  Boolean $manage_fw             = true,
  Boolean $optimize_kernel       = true,
  Stdlib::Absolutepath $data_dir = '/srv/ontoportal/data/agraph',
  $fwsrc                         = undef,
  $license                       = undef,
) {

  package { $package_name:
    ensure => $ensure,
    source => $source_url,
  }

  service { 'agraph':
    ensure  => $service_ensure,
    require => Package[$package_name]
  }
  if $optimize_kernel {
  sysctl { 'vm.overcommit_memory': value => '1' }
  include disable_transparent_hugepage
  }

  if $manage_fw {
    firewall_multi { "33 allow agraph on port ${port}":
      source => $fwsrc,
      dport  => $port,
      proto  => tcp,
      action => accept,
    }
  }

  user { 'agraph':
    ensure  => 'present',
    comment => 'AllegroGraph',
    system  => true,
    home    => '/var/lib/agraph',
    shell   => '/bin/bash',
  }

  file { '/etc/agraph':
    ensure => directory,
    mode   => '0755',
    owner  => root,
    group  => root,
  }

  $inline_agraph_cnf = @("EOF"/L)
    # AllegroGraph configuration file
    RunAs agraph
    Port ${port}
    SettingsDirectory ${data_dir}/settings
    LogDir /var/log/agraph
    PidFile /var/run/agraph/agraph.pid
    InstanceTimeout 604800

    <RootCatalog>
    Main ${data_dir}/rootcatalog
    </RootCatalog>

    <SystemCatalog>
    Main ${data_dir}/systemcatalog
    InstanceTimeout 10
    </SystemCatalog>

    ${license}

    | EOF

  file { '/etc/agraph/agraph.cfg':
    ensure  => present,
    mode    => '0644',
    owner   => root,
    group   => root,
    content => $inline_agraph_cnf,
  }

  file { [$data_dir, "${data_dir}/settings", "${data_dir}/settings/user"]:
    ensure  => directory,
    mode    => '0700',
    owner   => agraph,
    group   => agraph,
    require => User[agraph],
  }

  file { "${data_dir}/settings/user/super":
    mode    => '0600',
    owner   => agraph,
    group   => agraph,
    content => '(#x3b74c0e3a9d8517db3e3d3009f18580507438674 (:super) nil nil nil)\n'
  }

}

# @summary Role class for configuring the OntoPortal Appliance
#
# This class configures the base system for the OntoPortal virtual appliance.
# It sets up users, system packages, system services, application directories, and roles for the UI/API.
#
# Intended to be used as a top-level "role" class during image building or provisioning.
#
# @param ui Whether to enable the UI component.
# @param api Whether to enable the API component.
# @param manage_firewall Whether to manage firewall rules.
# @param manage_letsencrypt Whether to manage Let's Encrypt SSL certificate generation.
# @param manage_selinux Whether to configure SELinux (not fully supported).
# @param manage_va_repo Whether to clone the virtual appliance Git repository.
# @param manage_ssh_user Whether to create an sysadmin user for ssh logins (also enabled during Packer builds).
# @param ssh_user ssh login account
# @param owner The Unix owner for application files and directories.
# @param group The Unix group for application files and directories.
# @param appliance_version The version of the OntoPortal appliance to deploy.
# @param data_dir The root directory for data volumes.
# @param app_root_dir The root directory for the application code.
# @param api_port The HTTP port for the API server.
# @param api_port_https The HTTPS port for the API server.
# @param ui_domain_name The domain name to use for the UI component.
# @param api_domain_name The domain name to use for the API component.
# @param api_ruby_version The Ruby version to use for the API component.
# @param ui_ruby_version The Ruby version to use for the UI component (defaults to API version).
# @param goo_cache_maxmemory Max memory allocated to the Goo cache layer.
# @param http_cache_maxmemory Max memory allocated to the HTTP cache layer.
#
class ontoportal::appliance (
  Boolean $ui                        = true,
  Boolean $api                       = true,
  Boolean $manage_firewall           = true,
  Boolean $manage_letsencrypt        = false,
  Boolean $manage_selinux            = false,
  Boolean $manage_va_repo            = false,
  Boolean $manage_ssh_user           = false,
  String $ssh_user                   = 'ubuntu',
  String $owner                      = 'ontoportal',
  String $group                      = 'ontoportal',
  String $appliance_version          = '4.0',
  Stdlib::Absolutepath $data_dir     = '/srv/ontoportal/data',
  Stdlib::Absolutepath $app_root_dir = '/opt/ontoportal',
  Stdlib::Port $api_port             = 8080,
  Stdlib::Port $api_port_https       = 8443,
  String $ui_domain_name             = 'appliance.ontoportal.org',
  String $api_domain_name            = 'data.appliance.ontoportal.org',
  String $api_ruby_version           = '3.1.6',
  String $ui_ruby_version            =  $api_ruby_version,
  String $goo_cache_maxmemory        = '512M',
  String $http_cache_maxmemory       = '512M',
) {
  if $manage_firewall {
    require ontoportal::firewall
    include ontoportal::firewall::ssh
  }

  # disable puppet agent since we run it in a masterless mode
  service { 'puppet':
    ensure => 'stopped',
    enable => false,
  }

  # system utilities/libraries
  case $facts['os']['family'] {
    # EL is not fully supported
    'RedHat': {
      require epel
      Class[epel] -> Class[nginx]
      $packages = [
        'cloud-utils-growpart', #automatically grows partition on first deployment
        'git-lfs',
        'bind-utils',
        'bzip2',
        'bash-completion',
        'curl',
        'lsof',
        'ncdu',
        'nano',
        'htop',
        'rsync',
        'screen',
        'sysstat',
        'time',
        'unzip',
        'vim-enhanced',
        'wget',
        'zip',
        'rdate',
        'tree',
        'tmux',
        'yum-utils',
        'telnet',
      ]
      $packages_purge = [
        'linux-firmware',
      ]
    }
    'Debian': {
      $packages = [
        'git-lfs',
        'bind9-dnsutils',
        'bzip2',
        'bash-completion',
        'curl',
        'lsof',
        'ncdu',
        'nano',
        'htop',
        'rsync',
        'screen',
        'sysstat',
        'time',
        'unzip',
        'vim',
        'wget',
        'zip',
        'rdate',
        'tree',
        'tmux',
        'telnet',
      ]
      $packages_purge = [
        # 'openjdk-8-jre',
      ]
    }
    default: { fail('unsupported platform') }
  }

  stdlib::ensure_packages( $packages )
  stdlib::ensure_packages( $packages_purge, { ensure => 'absent' })

  class { 'systemd':
    manage_resolved  => true,
    manage_timesyncd => true,
    manage_journald  => true,
  }

  kernel_parameter { 'net.ifnames':
    value => '0',
  }

  class { 'motd':
    content => "OntoPortal Appliance v${appliance_version}\n",
  }

  #disable ssh root logins for AWS ami
  class { 'ssh::server':
    options => {
      'HostKey'              => [
        '/etc/ssh/ssh_host_ed25519_key',
        '/etc/ssh/ssh_host_rsa_key',
        '/etc/ssh/ssh_host_ecdsa_key',
      ],

      'PermitRootLogin'      => 'no',
      'PrintMotd'            => 'yes',
      'SyslogFacility'       => 'AUTHPRIV',
      'PermitEmptyPasswords' => 'no',
      # 'Ciphers'              => 'aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com',
    },
  }

  ##http://lonesysadmin.net/2013/12/06/use-elevator-noop-for-linux-virtual-machines/
  ##https://kb.vmware.com/s/article/2011861
  #if $is_virtual {
  #  kernel_parameter { "elevator":
  #    ensure  => present,
  #    value => "noop",
  #  }
  #  sysctl {'vm.swappiness': value => '0' }
  #}

  user { 'ontoportal':
    ensure     => 'present',
    comment    => 'OntoPortal Service Account',
    system     => true,
    managehome => true,
    # ontoportal user needs to copy war files for deployment so adding to tomcat group is an easy fix but could be problematic
    # groups     => ['tomcat'],
    password   => '!!',
    shell      => '/bin/bash',
    uid        => '888',
  }

  # optionally create ssh login account; don't create it in aws ami
  if ($manage_ssh_user or $facts['packer_build']) and !$facts['ec2_metadata'] {
    # OntoPortal system administator
    user { $ssh_user:
      ensure     => 'present',
      comment    => 'OntoPortal SysAdmin',
      shell      => '/bin/bash',
      password   => '$6$xZ2Tljdh8zYaXxCf$Op/5Hrf4fd/3Ayn2xVy5oopcdyf1Qp8Tf3.K2gAONA7LmOoJsaLoVjeeW7DXVnv3Y.qf2qq7dsWSUiAyLiJJM1',
      managehome => true,
    }

    sudo::conf { $ssh_user:
      content => "${ssh_user} ALL=(ALL) NOPASSWD: ALL",
    }
  }

  file { '/home/ontoportal/.gemrc':
    owner   => 'ontoportal',
    mode    => '0644',
    content => 'install: --no-document',
    require => User['ontoportal'],
  }

  file { '/etc/profile.d/ontoportal.sh':
    owner  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/ontoportal/etc/profile.d/ontoportal.sh',
  }

  group { 'ontoportal':
    ensure => present,
    gid    => '888',
  }

  file_line { 'ontoportal ruby gem path':
    path    => '/home/ontoportal/.bashrc',
    line    => 'which ruby >/dev/null && which gem >/dev/null && PATH="$(ruby -r rubygems -e \'puts Gem.user_dir\')/bin:$PATH"',
    require => User['ontoportal'],
  }

  # Create Directories (including parent directories)
  file { [$app_root_dir,
    ]:
      ensure => directory,
      owner  => $owner,
      group  => $group,
      mode   => '0775',
  }

  # tomcat is installed on both ui for biomixer and api for annotator+
  class { 'ontoportal::tomcat':
    port   => 8082,
  }

  if $ui {
    contain ontoportal::appliance::ui
  }

  if $api {
    contain ontoportal::appliance::api
  }

  $sudo_string = 'Cmnd_Alias ONTOPORTAL = /usr/local/bin/oprestart, /usr/local/bin/opstop, /usr/local/bin/opstart, /usr/local/bin/opstatus, /usr/local/bin/opclearcaches
Cmnd_Alias NGINX = /bin/systemctl start nginx, /bin/systemctl stop nginx, /bin/systemctl restart nginx
Cmnd_Alias NCBO_CRON = /bin/systemctl start ncbo_cron, /bin/systemctl stop ncbo_cron, /bin/systemctl restart ncbo_cron
Cmnd_Alias SOLR = /bin/systemctl start solr, /bin/systemctl stop solr, /bin/systemctl restart solr
Cmnd_Alias FSHTTPD = /bin/systemctl start 4s-httpd, /bin/systemctl stop 4s-httpd, /bin/systemctl restart 4s-httpd
Cmnd_Alias FSBACKEND = /bin/systemctl start 4s-backend, /bin/systemctl stop 4s-backend, /bin/systemctl restart 4s-backend
Cmnd_Alias FSBOSS = /bin/systemctl start 4s-boss, /bin/systemctl stop 4s-boss, /bin/systemctl restart 4s-boss
Cmnd_Alias REDIS = /bin/systemctl start redis-server-*.service , /bin/systemctl stop redis-server-*.service , /bin/systemctl restart redis-server-*.service
Cmnd_Alias UTILS = /usr/sbin/virt-what, /opt/ontoportal/virtual_appliance/utils/bootstrap/gen_tlscert.sh
Cmnd_Alias AG = /usr/sbin/service agraph start, /usr/sbin/service agraph status /usr/sbin/service agraph stop
ontoportal ALL = NOPASSWD: ONTOPORTAL, NGINX, NCBO_CRON, SOLR, FSHTTPD, FSBACKEND, FSBOSS, REDIS, UTILS, AG
'

  #do not purge sudo config files.  packer build relies on them.
  class { 'sudo':
    purge  => false,
    # config_file_replace => false,
  }

  sudo::conf { 'appliance':
    source => 'puppet:///modules/ontoportal/etc/sudoers.d/appliance',
  }

  file_line { 'add appliance ip to /etc/issue':
    path => '/etc/issue',
    line => 'OntoPortal Appliance IP: \4',
  }

  #utils
  file { '/usr/local/bin/oprestart':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/oprestart",
  }
  file { '/usr/local/bin/opstop':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opstop",
  }
  file { '/usr/local/bin/opstart':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opstart",
  }
  file { '/usr/local/bin/opstatus':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opstatus",
  }
  file { '/usr/local/bin/opclearcaches':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opclearcaches",
  }

  if $manage_va_repo {
    vcsrepo { "${app_root_dir}/virtual_appliance":
      ensure   => present,
      provider => git,
      user     => $owner,
      group    => $group,
      source   => 'https://github.com/ncbo/virtual_appliance',
      branch   => $appliance_version,
      require  => User[$owner],
      after    => File["${app_root_dir}/virtual_appliance"],
    }
  }

  file { "${app_root_dir}/virtual_appliance":
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0755',
  }

  # systemd service for the initial appliance configuration.
  # Ideally it should be executed by cloud-init but it is supported on all platforms so we rely on systemd
  # https://cloudinit.readthedocs.io/en/latest/topics/boot.html
  # fistboot script needs to run after cloud-init is completely done.
  systemd::unit_file { 'ontoportal-firstboot.service':
    ensure  => present,
    content => epp ('ontoportal/firstboot.service.epp', {
      'app_root' => $app_root_dir,
    }),
  }
  -> service { 'ontoportal-firstboot':
    enable => true,
  }
}

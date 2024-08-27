########################################################################

# this is more of a role than a profile.
class ontoportal::appliance (
  Boolean $ui                        = true,
  Boolean $api                       = true,
  String $owner                      = 'ontoportal',
  String $group                      = 'ontoportal',
  String $appliance_version          = '4.0-alpha',
  Stdlib::Absolutepath $data_dir     = '/srv/ontoportal/data',
  Stdlib::Absolutepath $app_root_dir = '/srv/ontoportal',
  Stdlib::Port $api_port             = 8080,
  Stdlib::Port $api_tls_port         = 8443,
  Boolean $manage_selinux            = false,
  String api_ruby_version            = '2.7.8',
  String ui_ruby_version             = '3.0.6',
) {
  include ontoportal::firewall
  include ontoportal::firewall::ssh

  # system utilities/libraries
  case $facts['os']['family'] {
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
    }
    default: { fail('unsupported platform') }
  }

  ensure_packages( $packages )

  #FIXME add DNS caching
  #  include nscd
  #nsswitch::hosts: ['files resolve [!UNAVAIL=return] dns']

  kernel_parameter { 'net.ifnames':
    value => '0',
  }

  class { 'motd':
    content => "OntoPortal Appliance v${appliance_version}\n",
  }

  # need to disable root ssh for AWS ami
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
      'Ciphers'              => 'aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com',
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

  include git

  ensure_packages([
      'linux-firmware',
    ],
    { ensure => absent },
  )

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

  file { '/home/ontoportal/.gemrc':
    owner   => 'ontoportal',
    mode    => '0644',
    content => 'install: --no-document',
    require => User['ontoportal'],
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

  # ssh user
  user { 'admin':
    ensure     => 'present',
    comment    => 'OntoPortal SysAdmin User',
    managehome => true,
    # password is set primarely for packaging appliance via packer and it is reset by cleanup scripts
    password   => '$6$z3zd7CSW$zlHFTTjkpBVp8fhpi5ZwdDxHFd.bfBK/b9jktYWwueLY/ddUf.31Y2zDcIsGuNQ4L/qBHoE8MCJXraQICAldX.',
    shell      => '/bin/bash',
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
Cmnd_Alias UTILS = /usr/sbin/virt-what, /srv/ontoportal/virtual_appliance/utils/bootstrap/gen_tlscert.sh
Cmnd_Alias AG = /usr/sbin/service agraph start, /usr/sbin/service agraph status /usr/sbin/service agraph stop
ontoportal ALL = NOPASSWD: ONTOPORTAL, NGINX, NCBO_CRON, SOLR, FSHTTPD, FSBACKEND, FSBOSS, REDIS, UTILS, AG
'

  #do not purge sudo config files.  packer build relies on them.
  class { 'sudo':
    # purge               => false,
    # config_file_replace => false,
  }

  # required for vagrant builds but is removed in the cleanup/packaging step
  sudo::conf { 'vagrant':
    content => 'vagrant ALL=(ALL) NOPASSWD: ALL',
  }

  sudo::conf { 'admin':
    content => 'admin ALL=(ALL) NOPASSWD: ALL',
  }

  sudo::conf { 'appliance':
    content => $sudo_string,
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
  vcsrepo { "${app_root_dir}/virtual_appliance":
    ensure   => present,
    provider => git,
    user     => $owner,
    group    => $group,
    source   => 'https://github.com/ncbo/virtual_appliance',
    branch   => $appliance_version,
    require  => User[$owner],
  }

  -> file { "${app_root_dir}/virtual_appliance":
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0755',
  }

  # systemd service for the initial appliance configuration.
  # Ideally it should be executed by cloud-init but it is supported on all platforms so we rely on systemd
  # https://cloudinit.readthedocs.io/en/latest/topics/boot.html
  # fistboot script needs to run after cloud-init is completely done.
  $firstboot = @("FIRSTBOOT"/L)
    [Unit]
    Description=Initial Ontoportal Appliance reconfiguration which runs only on first boot.
    After=network-online.target cloud-final.service 4s-boss.service 4s-backend.service 4s-httpd.service redis-server-goo.service redis-server-http.service redis-server-persistent.service nginx.service
    ConditionPathExists=${app_root_dir}/firstboot

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStartPre=/usr/bin/sleep 5
    ExecStart=${app_root_dir}/virtual_appliance/utils/bootstrap/firstboot.rb
    ExecStartPost=/usr/bin/rm ${app_root_dir}/firstboot
    User=ontoportal
    Group=ontoportal
    TimeoutSec=0
    StandardOutput=journal+console

    [Install]
    WantedBy=multi-user.target
    | FIRSTBOOT

  systemd::unit_file { 'ontoportal-firstboot.service':
    ensure  => present,
    content => $firstboot,
  }
  -> service { 'ontoportal-firstboot':
    enable => true,
  }
}

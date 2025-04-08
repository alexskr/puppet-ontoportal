class ontoportal::appliance::system (

  # System integration options
  Boolean $manage_firewall = true,
  Boolean $manage_selinux = false,
  String  $appliance_version,
  String $java_pkg_name = 'openjdk-11-jre-headless',

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

  class { 'java':
    package => $java_pkg_name,
  }

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

  #do not purge sudo config files.  packer build relies on them.
  class { 'sudo':
    purge  => false,
    # config_file_replace => false,
  }

  file_line { 'add appliance ip to /etc/issue':
    path => '/etc/issue',
    line => 'OntoPortal Appliance IP: \4',
  }

}

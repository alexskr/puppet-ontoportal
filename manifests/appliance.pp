########################################################################


# this should be moved to role
class ontoportal::appliance(
  $owner = 'ontoportal',
  $group = 'ontoportal',
  $appliance_version = '3.0',
  $ruby_version = '2.6.7',
  $data_dir = '/srv/ontoportal/data',
  $app_root_dir  = '/srv/ontoportal',
  $ui_domain_name = 'appliance.ontoportal.org',
  $api_domain_name = 'data.appliance.ontoportal.org',
  ){
    #  user { 'root':
    #password           => '$1$nCrHx6ct$0O.NJ8EDhHh3NJSK1yMU./',
    #}
  include nscd

  kernel_parameter {'net.ifnames':
    value => '0',
  }
  require epel
  class { 'motd':
    content => "OntoPortal Appliance v${appliance_version}\n"
  }

  # need to disable root ssh for AWS ami
  class { 'ssh::server':
    options   => {
      'HostKey'              => [
        '/etc/ssh/ssh_host_ed25519_key',
        '/etc/ssh/ssh_host_rsa_key',
        '/etc/ssh/ssh_host_ecdsa_key'],

      'PermitRootLogin'      => 'no',
      'PrintMotd'            => 'yes',
      'SyslogFacility'       => 'AUTHPRIV',
      'PermitEmptyPasswords' => 'no',
    }
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

  case $::virtual {
    'vmware': {
      include openvmtools
    }
    'z': { #disabled this for the time being; it is currently handled with scripts during packaging 
      package { 'cloud-init':
        ensure => installed,
      }
      -> package { 'cloud-init-vmware-guestinfo':
        ensure => installed,
        source => 'https://github.com/vmware/cloud-init-vmware-guestinfo/releases/download/v1.1.0/cloud-init-vmware-guestinfo-1.1.0-1.el7.noarch.rpm'
      }
      package { 'cloud-utils-growpart': #automatically grows partition on first deployment
        ensure => installed,
      }
    }
  }

  # odd depenency cyle workaround - rbenv installs git and git class gets included somewere
  class { 'git':
    package_manage => false
  }

  # system utilities/libraries
  ensure_packages([
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
    'which',
    'wget',
    'zip',
    'rdate',
    'tree',
    'tmux',
    'yum-utils',
    'telnet'
  ])

  ensure_packages([
    'linux-firmware',
  ],
    { ensure =>  absent}
  )

  include ontoportal::firewall
  include ontoportal::firewall::ssh
  include ontoportal::firewall::http
  include ontoportal::firewall::p8080
  ##aws cloud-init
## ensure_packages (['cloud-init'])
##   file { '/etc/cloud/cloud.cfg.d/08_ontoportal.cfg':
##     ensure  => present,
##     owner   => root,
##     group   => root,
##     mode    => '0644',
##     content => '#cloud-config
## runcmd:
##  - ${app_root_dir}/virtual_appliance/utils/bootstrap/firstboot.rb
##  - rm /root/firstboot
## ',
##   }

  user { 'ontoportal':
    ensure     => 'present',
    comment    => 'OntoPortal Service Account',
    system     => true,
    managehome => true,
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
  file_line {'ontoportal ruby gem path':
    path =>  '/home/ontoportal/.bashrc',
    line => 'which ruby >/dev/null && which gem >/dev/null && PATH="$(ruby -r rubygems -e \'puts Gem.user_dir\')/bin:$PATH"',
  }

  # ssh user
  user { 'centos':
    ensure     => 'present',
    comment    => 'OntoPortal SysAdmin User',
    managehome => true,
    # password is set primarely for packaging appliance and will be reset by cleanup scripts
    password   => '$6$z3zd7CSW$zlHFTTjkpBVp8fhpi5ZwdDxHFd.bfBK/b9jktYWwueLY/ddUf.31Y2zDcIsGuNQ4L/qBHoE8MCJXraQICAldX.',
    shell      => '/bin/bash',
  }
  # Create Directories (including parent directories)
  file { [$app_root_dir,
  #         "${app_root_dir}/.bundle",
          $data_dir,
          "${data_dir}/reports", "${data_dir}/mgrep",
          "${data_dir}/mgrep/dictionary/"]:
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0775',
  }
  class { 'ontoportal::rbenv':
    ruby_version => $ruby_version,
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
  Class['ontoportal::tomcat'] -> Class['ontoportal::ncbo_cron']
  # chaining api and UI,  sometimes passenger yum repo confuses nginx installation.
  Class['epel'] -> Class['ontoportal::ontologies_api'] -> Class['ontoportal::bioportal_web_ui']

  class {'ontoportal::bioportal_web_ui':
    environment       => 'appliance',
    ruby_version      => $ruby_version,
    owner             => $owner,
    group             => $group,
    enable_mod_status => false,
    logrotate_httpd   => 7,
    logrotate_rails   => 7,
    railsdir          => "${app_root_dir}/bioportal_web_ui",
    domain            => $ui_domain_name,
    slices            => [],
    enable_ssl        => true,
    # self-generated certificats
    ssl_cert          => '/etc/pki/tls/certs/localhost.crt',
    ssl_key           => '/etc/pki/tls/private/localhost.key',
    ssl_chain         => '/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt',
    install_ruby      => false,
    require           => Class['ontoportal::rbenv'],
  }
  class {'ontoportal::ontologies_api':
    environment         => 'appliance',
    port                => 8080,
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

  class {'ontoportal::redis_goo_cache':
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
  fourstore::kb { 'ontoportal_api': segments => 4 }

  class { 'mgrep':
    mgrep_enable => true,
    group        => $group,
    dict_path    => "${data_dir}/mgrep/dictionary/dictionary.txt"
  }
  include mgrep::dictrefresh

  # mod_proxy is needed for reverse proxy of biomixer and annotator plus proxy
  include apache::mod::proxy
  include apache::mod::proxy_http

  ##mysql setup
  class {'mysql::server':
    remove_default_accounts => true,
    override_options        => {
      'mysqld'                           => {
        'innodb_buffer_pool_size'        => '64M',
        'innodb_flush_log_at_trx_commit' => '0',
        'innodb_file_per_table'          => '',
        'innodb_flush_method'            => 'O_DIRECT',
        'character-set-server'           => 'utf8',
      },
    }
  }
  # annotator plus proxy reverse proxy
  nginx::resource::location { '/annotatorplus/':
    ensure => present,
    # ssl   => false,
    server => 'ontologies_api',
    proxy  => 'http://localhost:8082/annotatorplus/',
  }

  class { 'mysql::client': }
  mysql::db { 'bioportal_web_ui_appliance':
    user     => 'bp_ui_appliance',
    password => '*EBE8A8D53522BAC12B99F606FC3C3757742DE6FB',
    host     => 'localhost',
    grant    => ['ALL'],
  }

  class { 'memcached':
    max_memory    =>  '512m',
    max_item_size =>  '5M',
  }

  class { 'ontoportal::tomcat':
    port     => 8082,
    webadmin => false,
  }

  # add placeholder files with proper permissions for deployment
  -> file { ['/usr/share/tomcat/webapps/biomixer.war',
          '/usr/share/tomcat/webapps/annotatorplus.war' ]:
    replace => 'no',
    content => 'placeholder',
    mode    => '0644',
    owner   => $owner,
  }
  class { 'selinux':
    mode => disabled
  }
  $sudo_string = 'Cmnd_Alias ONTOPORTAL = /usr/local/bin/oprestart, /usr/local/bin/opstop, /usr/local/bin/opstart, /usr/local/bin/opstatus, /usr/local/bin/opclearcaches
Cmnd_Alias NGINX = /bin/systemctl start nginx, /bin/systemctl stop nginx, /bin/systemctl restart nginx
Cmnd_Alias NCBO_CRON = /bin/systemctl start ncbo_cron, /bin/systemctl stop ncbo_cron, /bin/systemctl restart ncbo_cron
Cmnd_Alias SOLR = /bin/systemctl start solr, /bin/systemctl stop solr, /bin/systemctl restart solr
Cmnd_Alias FSHTTPD = /bin/systemctl start 4s-httpd, /bin/systemctl stop 4s-httpd, /bin/systemctl restart 4s-httpd
Cmnd_Alias FSBACKEND = /bin/systemctl start 4s-backend, /bin/systemctl stop 4s-backend, /bin/systemctl restart 4s-backend
Cmnd_Alias FSBOSS = /bin/systemctl start 4s-boss, /bin/systemctl stop 4s-boss, /bin/systemctl restart 4s-boss
Cmnd_Alias REDIS = /bin/systemctl start redis-server-*.service , /bin/systemctl stop redis-server-*.service , /bin/systemctl restart redis-server-*.service
Cmnd_Alias UTILS = /usr/sbin/virt-what
Cmnd_Alias AG = /usr/sbin/service agraph start, /usr/sbin/service agraph status /usr/sbin/service agraph stop
ontoportal ALL = NOPASSWD: ONTOPORTAL, NGINX, NCBO_CRON, SOLR, FSHTTPD, FSBACKEND, FSBOSS, REDIS, UTILS, AG'


  #do not purge sudo config files.  packer build relies on them.
  class { 'sudo':
    #    purge               => false,
    #      config_file_replace => false,
  }

  sudo::conf {'vagrant':
    content  => '%vagrant ALL=(ALL) NOPASSWD: ALL',
  }

  sudo::conf {'centos':
    content  => '%centos ALL=(ALL) NOPASSWD: ALL',
  }

  sudo::conf {'appliance':
    content  => $sudo_string,
  }

  $issue_string='\S
Kernel \r on an \m
OntoPortal Appliance IP: \4
'

  file {'/etc/issue':
    owner   => root,
    group   => root,
    mode    => '0644',
    content => $issue_string,
  }
  # sudo::conf { 'vagrant':
  #   priority => '10',
  #   content  => 'vagrant ALL=(ALL) NOPASSWD: ALL',
  # }
  #utils
  file {'/usr/local/bin/oprestart':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/oprestart",
  }
  file {'/usr/local/bin/opstop':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opstop",
  }
  file {'/usr/local/bin/opstart':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opstart",
  }
  file {'/usr/local/bin/opstatus':
    ensure => symlink,
    target => "${app_root_dir}/virtual_appliance/utils/opstatus",
  }
  file {'/usr/local/bin/opclearcaches':
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
  }

  -> file { "${app_root_dir}/virtual_appliance":
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0755',
  }

  # https://cloudinit.readthedocs.io/en/latest/topics/boot.html
  # fist boot needs to run after cloud-init is completely done.
  $firstboot = @("FIRSTBOOT"/L)
    [Unit]
    Description=Initial Ontoportal Appliance reconfiguration which runs only on first boot.
    After=network-online.target cloud-final.service 4s-boss.service 4s-backend.service 4s-httpd.service redis-server-goo.service redis-server-http.service redis-server-persistent.service nginx.service
    ConditionPathExists=${app_root_dir}/firstboot
    #Before=getty@tty6.service

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

  systemd::unit_file {'ontoportal-firstboot.service':
    ensure  => present,
    content => $firstboot,
  }
  -> service { 'ontoportal-firstboot':
    enable => true,
  }

  class { 'ontoportal::agraph':
    service_ensure => false,
    manage_fw      => false,
    version        => '7.0.4',
  }
}

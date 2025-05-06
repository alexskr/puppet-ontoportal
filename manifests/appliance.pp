# @summary Role class for configuring the OntoPortal Appliance
#
# This class configures the base system for the OntoPortal virtual appliance.
# It sets up users, system packages, system services, application directories, and roles for the UI/API.
#
# Intended to be used as a top-level "role" class during image building or provisioning.
#
# @param include_ui Whether to enable the UI component.
# @param include_api Whether to enable the API component.
# @param manage_firewall Whether to manage firewall rules.
# @param manage_letsencrypt Whether to manage Let's Encrypt SSL certificate generation.
# @param manage_selinux Whether to configure SELinux (not fully supported).
# @param manage_va_repo Whether to clone the virtual appliance Git repository.
# @param manage_ssh_user Whether to create an sysadmin user for ssh logins (also enabled during Packer builds).
# @param sysadmin_user sysadmin local account
# @param admin_user OntoPortal deployer/admin/ops user
# @param backend_user service account for running API and ncbo_cron services.
# @param ui_user service account for running UI/puma/rails services.
# @param shared_group The Unix group for application data.
# @param appliance_version The version of the OntoPortal appliance to deploy.
# @param data_dir The root directory for data volumes.
# @param app_root_dir The root directory for the application code.
# @param log_root_dir The root directory for the application logs.
# @param api_port The HTTP port for the API server.
# @param api_port_https The HTTPS port for the API server.
# @param ui_domain_name The domain name to use for the UI component.
# @param api_domain_name The domain name to use for the API component.
# @param api_ruby_version The Ruby version to use for the API component.
# @param ui_ruby_version The Ruby version to use for the UI component (defaults to API version).
# @param goo_cache_maxmemory Max memory allocated to the Goo cache layer.
# @param http_cache_maxmemory Max memory allocated to the HTTP cache layer.
# @param triple_store triple store backend to manage can be 4store, agraph or external.
#
class ontoportal::appliance (

  # Feature toggles
  Boolean $include_ui  = true,
  Boolean $include_api = true,
  Enum['4store', 'agraph', 'external'] $triple_store = 'agraph',

  # System integration options
  Boolean $manage_firewall    = true,
  Boolean $manage_letsencrypt = false,
  Boolean $manage_selinux     = false,
  Boolean $manage_va_repo     = false,
  Boolean $manage_ssh_user    = true,

  # Users & permissions
  String $admin_user         = 'op-admin',
  String $backend_user       = 'op-backend',
  String $ui_user            = 'op-ui',
  String $shared_group       = 'opdata',
  String $sysadmin_user      = 'ubuntu',

  Boolean $manage_admin_user    = true,
  Boolean $manage_sysadmin_user = false,

  Array[String] $admin_sshkeys    = [],
  Array[String] $sysadmin_sshkeys = [],

  # Paths
  Stdlib::Absolutepath $app_root_dir = '/opt/ontoportal',
  Stdlib::Absolutepath $data_dir     = '/srv/ontoportal',
  Stdlib::Absolutepath $log_root_dir = '/var/log/ontoportal',

  # Application settings
  String $appliance_version    = '4.0',
  Stdlib::Port $api_port       = 8080,
  Stdlib::Port $api_port_https = 8443,
  Boolean $enable_https        = true,

  # Domain & Ruby versions
  String $ui_domain_name   = 'demo.ontoportal.org',
  String $api_domain_name  = 'data.demo.ontoportal.org',
  String $ui_ruby_version  = '3.1.6',
  String $api_ruby_version = $ui_ruby_version,

  # Memory tuning
  String $goo_cache_maxmemory  = '512M',
  String $http_cache_maxmemory = '512M',

  # Log rotate/retention
  Integer $logrotate_ui = 14,
  Integer $logrotate_nginx = 14,

) {
  Class['ontoportal::appliance::system']
  -> Class['ontoportal::appliance::user']
  -> Class['ontoportal::appliance::layout']

  class { 'ontoportal::appliance::system':
    manage_firewall   => $manage_firewall,
    appliance_version => $appliance_version,
  }

  # optionally create ssh login account; don't create it in aws ami
  $_manage_sysadmin_user = ($manage_sysadmin_user or $facts['packer_build']) and !$facts['ec2_metadata']

  class { 'ontoportal::appliance::user':
    admin_user           => $admin_user,
    ui_user              => $ui_user,
    backend_user         => $backend_user,
    sysadmin_user        => $sysadmin_user,
    shared_group         => $shared_group,
    manage_sysadmin_user => $_manage_sysadmin_user,
    admin_sshkeys        => $admin_sshkeys,
    sysadmin_sshkeys     => $sysadmin_sshkeys,
  }

  file { '/etc/profile.d/ontoportal.sh':
    owner   => 'root',
    mode    => '0644',
    content => epp('ontoportal/etc/profile.d/ontoportal', {
        #  'data_dir'     => $data_dir,
        'app_root_dir' => $app_root_dir,
        'log_dir'      => $log_root_dir,
        'admin_user'   => $admin_user,
    }),
  }

  # tomcat is installed on both ui for biomixer and api for annotator+
  class { 'ontoportal::tomcat':
    port => 8082,
  }

  class { 'ontoportal::appliance::layout':
    include_ui   => $include_ui,
    include_api  => $include_api,
    app_root_dir => $app_root_dir,
    log_root_dir => $log_root_dir,
    data_dir     => $data_dir,
    admin_user   => $admin_user,
    backend_user => $backend_user,
    ui_user      => $ui_user,
    shared_group => $shared_group,
  }

  if $include_ui {
    class { 'ontoportal::appliance::ui':
      ui_domain_name     => $ui_domain_name,
      app_root_dir       => $app_root_dir,
      log_dir            => $log_root_dir,
      ruby_version       => $ui_ruby_version,
      admin_user         => $admin_user,
      group              => $ui_user,
      ui_user            => $ui_user,
      manage_firewall    => $manage_firewall,
      manage_letsencrypt => $manage_letsencrypt,
      enable_https       => $enable_https,
      logrotate_ui       => $logrotate_ui,
      logrotate_nginx    => $logrotate_nginx,
    }
    Class['ontoportal::appliance::layout'] ->  Class['ontoportal::appliance::ui']
  }

  if $include_api {
    class { 'ontoportal::appliance::api':
      app_root_dir         => $app_root_dir,
      log_root_dir         => $log_root_dir,
      data_dir             => $data_dir,
      admin_user           => $admin_user,
      backend_user         => $backend_user,
      shared_group         => $shared_group,
      appliance_version    => $appliance_version,
      api_domain_name      => $api_domain_name,
      ruby_version         => $api_ruby_version,
      owner                => $admin_user,
      group                => $shared_group,
      manage_letsencrypt   => $manage_letsencrypt,
      manage_firewall      => $manage_firewall,
      goo_cache_maxmemory  => $goo_cache_maxmemory,
      http_cache_maxmemory => $http_cache_maxmemory,
      api_port             => $api_port,
      api_port_https       => $api_port_https,
      enable_https         => $enable_https,
      triple_store         => $triple_store,
    }
    Class['ontoportal::appliance::layout'] ->  Class['ontoportal::appliance::api']
  }

  sudo::conf { 'appliance':
    content => epp('ontoportal/etc/sudoers.d/appliance', {
        'user' => $admin_user,
    }),
  }

  # wrapper for managing services
  file { '/usr/local/ontoportal/bin/opctl':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => epp('ontoportal/usr/local/bin/opctl.epp', {
        'triple_store' => $triple_store,
        'include_api'  => $include_api,
        'include_ui'   => $include_ui,
        'app_root_dir' => $app_root_dir,
        'log_dir'      => $log_root_dir,
        'data_dir'     => $data_dir,
        'admin_user'   => $admin_user,
        'backend_user' => $backend_user,
        'ui_user'      => $ui_user,
        'shared_group' => $shared_group,
    }),
  }
  -> file { '/usr/local/bin/opctl':
    ensure => simlink,
    target => '/usr/local/ontoportal/bin/opctl',
  }

  $va_path = "${app_root_dir}/virtual_appliance"

  # i don't really like it like this; but will fix it later
  file { '/usr/local/ontoportal/bin/infra_discovery.rb':
    ensure => file,
    source => "file://${va_path}/infra/infra_discovery.rb",
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/usr/local/ontoportal/bin/gen_tlscert':
    ensure => file,
    source => "file://${va_path}/infra/gen_tlscert",
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/usr/local/ontoportal/bin/cloudmeta':
    ensure => file,
    source => "file://${va_path}/infra/cloudmeta",
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  if $manage_va_repo {
    vcsrepo { $va_path:
      ensure   => present,
      provider => git,
      user     => $admin_user,
      group    => $admin_user,
      source   => 'https://github.com/ncbo/virtual_appliance',
      branch   => $appliance_version,
      require  => Class['ontoportal::user::admin'],
      after    => File[$va_path],
    }
  }

  # systemd service for the initial appliance configuration.
  # Ideally it should be executed by cloud-init but it is supported on all platforms so we rely on systemd
  # https://cloudinit.readthedocs.io/en/latest/topics/boot.html
  # fistboot script needs to run after cloud-init is completely done.
  systemd::unit_file { 'ontoportal-firstboot.service':
    ensure  => present,
    content => epp ('ontoportal/firstboot.service.epp', {
        'firstboot_lockfile' => "${app_root_dir}/config/firstboot",
        'firstboot_path'     => "${va_path}/infra/firstboot.rb",
        'user'               => $admin_user,
    }),
  }
  -> service { 'ontoportal-firstboot':
    enable => true,
  }
  include ontoportal::appliance::cleanup
}

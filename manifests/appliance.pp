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

  # Feature toggles
  Boolean $include_ui               = true,
  Boolean $include_api              = false,
  Enum['4store', 'agraph', 'external'] $triple_store = 'agraph',

  # System integration options
  Boolean $manage_firewall = false,
  Boolean $manage_letsencrypt = false,
  Boolean $manage_selinux = false,
  Boolean $manage_va_repo = false,
  Boolean $manage_ssh_user = true,

  # Users & permissions
  String $admin_user         = 'ontoportal-admin',
  String $backend_user       = 'ontoportal-backend',
  String $ui_user            = 'ontoportal-ui',
  String $shared_group       = 'ontoportal',
  String $sysadmin_user      = 'ubuntu',

  Boolean $manage_admin_user = true,
  Boolean $manage_sysadmin_user = false,
  Boolean $manage_shared_group = false,

  Array[String] $admin_sshkeys    = [],
  Array[String] $sysadmin_sshkeys = [],

  # Paths
  Stdlib::Absolutepath $app_root_dir = '/opt/ontoportal',
  Stdlib::Absolutepath $data_dir     = '/srv/ontoportal',
  Stdlib::Absolutepath $log_dir      = '/var/log/ontoportal',

  # Application settings
  String $appliance_version          = '4.0',
  Stdlib::Port $api_port           = 8080,
  Stdlib::Port $api_port_https     = 8443,

  # Domain & Ruby versions
  String $ui_domain_name   = 'demo.ontoportal.org',
  String $api_domain_name  = 'data.demo.ontoportal.org',
  String $ui_ruby_version  = '3.1.6',
  String $api_ruby_version = $ui_ruby_version,

  # Memory tuning
  String $goo_cache_maxmemory,
  String $http_cache_maxmemory,

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
    admin_user            => $admin_user,
    sysadmin_user         => $sysadmin_user,

    manage_sysadmin_user  => $_manage_sysadmin_user,
    manage_shared_group   => $manage_shared_group,

    admin_sshkeys        => $admin_sshkeys,
    sysadmin_sshkeys     => $sysadmin_sshkeys,
  }

  file { '/etc/profile.d/ontoportal.sh':
    owner  => 'root',
    mode   => '0644',
    content => epp('ontoportal/etc/profile.d/ontoportal', {
      #  'data_dir'     => $data_dir,
      'app_root_dir' => $app_root_dir,
      'log_dir'      => $log_dir,
      'admin_user'   => $admin_user,
    }),
  }

  # tomcat is installed on both ui for biomixer and api for annotator+
  class { 'ontoportal::tomcat':
    port   => 8082,
  }

  class { 'ontoportal::appliance::layout':
    include_ui     => $include_ui,
    include_api    => $include_api,
  }


  if $include_ui {
    class { 'ontoportal::appliance::ui':
      ui_domain_name     => $ui_domain_name,
      app_root_dir       => $app_root_dir,
      ruby_version       => $ui_ruby_version,
      admin_user         => $admin_user,
      # group              => $shared_group,
      manage_letsencrypt => $manage_letsencrypt,
      enable_https       => true,
    }
    Class['ontoportal::appliance::layout'] ->  Class['ontoportal::appliance::ui']
  }

  if $include_api {
    class { 'ontoportal::appliance::api':
      api_domain_name     => $api_domain_name,
      ruby_version        => $api_ruby_version,
      owner              => $admin_user,
      group               => $shared_group,
      manage_letsencrypt  => $manage_letsencrypt,
      goo_cache_maxmemory => $goo_cache_maxmemory,
      http_cache_maxmemory => $http_cache_maxmemory,
      api_port            => $api_port,
      api_port_https      => $api_port_https,
      enable_https        => true,
      triple_store        => $triple_store,
    }
    Class['ontoportal::appliance::layout'] ->  Class['ontoportal::appliance::api']
  }
  sudo::conf { 'appliance':
    source => 'puppet:///modules/ontoportal/etc/sudoers.d/appliance',
  }

  # wrapper for managing services
  file { '/usr/local/bin/opctl':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => epp('ontoportal/usr/local/bin/opctl.epp', {
      'triple_store' => $triple_store,
      'include_api'   => $include_api,
      'include_ui'    => $include_ui,
    }),
  }

  $va_path = "${app_root_dir}/virtual_appliance"

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
      'firstboot_lockfile'  => "${app_root_dir}/config/firstboot",
      'firstboot_path' => "${va_path}/utils/bootstrap/firstboot",
      'user'           => $admin_user,
    }),
  }
  -> service { 'ontoportal-firstboot':
    enable => true,
  }
  include ontoportal::appliance::cleanup
}

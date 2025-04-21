#
# Description: This class manages puma for ontoportal stack
#
define ontoportal::puma (
  String $app                        = $name,
  String $owner,
  String $group,
  String $admin_user,
  String $rails_env,
  Optional[String] $unit_environment = undef,
  Stdlib::Absolutepath $app_dir,
  Boolean $manage_nginx              = false,
  Optional[Integer] $puma_threads    = undef,
  Optional[Integer] $puma_workers    = $facts['processors']['count'],
  Stdlib::Absolutepath $bundle_bin   = '/usr/local/rbenv/shims/bundle',
  Optional[Array[Stdlib::Absolutepath]] $read_write_paths = [],
  Optional[Array[Stdlib::Absolutepath]] $read_only_paths = [],
  ){
  $puma = "puma-${name}"
  # Define the upstream Puma socket
  if $manage_nginx {
    nginx::resource::upstream { $puma:
      members => {
        'localhost' => {
          server       => "unix:/run/${puma}/puma.sock",
          fail_timeout => '0s',
      },}
    }
  }

  # https://github.com/puma/puma/blob/master/docs/deployment.md
  systemd::unit_file { "${app}.service":
    ensure  => 'present',
    content => epp ('ontoportal/puma.service.epp', {
      'name'             => $puma,
      'user'             => $owner,
      'group'            => $group,
      'app_dir'          => $app_dir,
      'bundle_bin'       => $bundle_bin,
      'rails_env'        => $rails_env,
      'environment'      => $unit_environment,
      'puma_threads'     => $puma_threads,
      'puma_workers'     => $puma_workers,
      'read_write_paths' => $read_write_paths,
      'read_only_paths'  => $read_only_paths,
      }),
  }
  ~> service { "${app}.service":
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

  # deployer needs sudo to restart unicorn
  sudo::conf { "${app}.service":
    priority =>  55,
    content =>   "${admin_user} ALL=(ALL) NOPASSWD: /bin/systemctl stop ${app}.service, /bin/systemctl start ${app}.service, /bin/systemctl restart ${app}.service",
  }
}



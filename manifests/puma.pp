#
# Description: This class manages puma for ontoportal stack
#
define ontoportal::puma (
  String $app                        = $name,
  String $owner                      = 'ontoportal',
  String $group                      = 'ontoportal',
  String $rails_env                  = "staging",
  Optional[String] $unit_environment = undef,
  Stdlib::Absolutepath $app_root,
  Boolean $manage_nginx              = false,
  Optional[Integer] $puma_threads    = undef,
  Optional[Integer] $puma_workers    = $facts['processors']['count'],
  Stdlib::Absolutepath $bundle_bin   = '/usr/local/rbenv/shims/bundle',
  ){

  # Define the upstream Puma socket
  if $manage_nginx {
    nginx::resource::upstream { "puma-${app}":
      members => {
        'localhost' => {
          server       => "unix:${app_root}/shared/tmp/sockets/puma.sock",
          fail_timeout => '0s',
      },}
    }
  }

  # https://github.com/puma/puma/blob/master/docs/deployment.md
  systemd::unit_file { "${app}.service":
    ensure  => 'present',
    content => epp ('ontoportal/puma.service.epp', {
      'name'         => $app,
      'user'         => $owner,
      'group'        => $group,
      'app_root'     => $app_root,
      'bundle_bin'   => $bundle_bin,
      'rails_env'    => $rails_env,
      'environment'  => $environment,
      'puma_threads' => $puma_threads,
      'puma_workers' => $puma_workers,
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
    content =>   "${owner} ALL=(ALL) NOPASSWD: /bin/systemctl stop ${app}.service, /bin/systemctl start ${app}.service, /bin/systemctl restart ${app}.service",
  }
}



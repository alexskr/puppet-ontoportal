#
# Class: ncbo::profile::bioportal_web_ui
#
# Description: This class manages bioportal_Web_ui, nginx/puma/rails setup for bioportal web ui
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:

define ontoportal::puma (
  String $app       = $name,
  String $owner              = 'ontoportal',
  String $group              = 'ontoportal',
  String $rails_env   = "staging",
  Optional[String] $environment = undef,
  Stdlib::Absolutepath $app_root,
  Stdlib::Port $port         = 80,
  Boolean $manage_nginx  = false,
  Optional[Integer] $puma_threads = undef,
  Optional[Integer] $puma_workers = $facts['processors']['count']/2,
  Stdlib::Absolutepath $bundle_bin  = '/usr/local/rbenv/shims/bundle',
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

  # nginx::resource::location { '@puma-bioportal_web_ui':
  #   ssl                => $ssl_enabled,
  #   proxy_http_version =>' 1.1',
  #   server             => 'ontoportal_web_ui',
  #   proxy              => 'http://puma-bioportal_web_ui',
  #   proxy_set_header   => [
  #     'X-Forwarded-For $proxy_add_x_forwarded_for',
  #     'Host $host',
  #     'X-Forwarded-Proto https',
  #     'X-Real-IP $remote_addr',
  #   ],
  # }

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



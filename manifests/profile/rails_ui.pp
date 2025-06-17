class ontoportal::profile::rails_ui (
  Enum['staging', 'production', 'appliance', 'development'] $environment = 'staging',
  String $ruby_version             = '3.1.6',
  String $admin_user               = 'op-admin',
  String $group                    = 'op-admin',
  String $service_account          = 'op-ui',
  Integer $logrotate_ui            = 14,
  Integer $puma_workers            = max(1, $facts['processors']['count']/2),
  Stdlib::Absolutepath $app_root_dir = '/opt/ontoportal',
  Stdlib::Absolutepath $app_dir    = "${app_root_dir}/bioportal_web_ui",
  Stdlib::Absolutepath $log_dir    = '/var/log/ontoportal/ui',
  String $domain                   = 'demo.ontoportal.org',
  Optional[Array[String]] $slices  = [], #used as SAN for letsencrypt
  Boolean $manage_ruby             = true,
  Stdlib::Absolutepath $bundle_bin = '/usr/local/rbenv/shims/bundle',
  Array[Stdlib::Absolutepath] $read_only_paths = ["${app_dir}/current"],
  Array[Stdlib::Absolutepath] $read_write_paths = [$log_dir],
) {
  case $facts['os']['family'] {
    'RedHat': {
      require epel
      stdlib::ensure_packages ([
        'mariadb-devel',
      ])
    }
    'Debian': {
      stdlib::ensure_packages ([
        'libmariadb-dev',
        'tzdata',
      ])
    }
  }

  include ontoportal::yarn

  if $manage_ruby {
    ontoportal::rbenv { $ruby_version:
      global => true,
      # rubygems_version => '3.5.16',
      # bundler_version  => '2.5.16',
    }
  }

  file { $log_dir:
    ensure => directory,
    owner  => $service_account,
    group  => $group,
    mode   => '0770';
  }

  #Create rails directory structure
  file {
    default:
      ensure => directory,
      owner  => $admin_user,
      group  => $group;

    [
      $app_dir,
      "${app_dir}/shared",
      "${app_dir}/releases",
      "${app_dir}/shared/system"
    ]:
      mode => '0755';

    "${app_dir}/shared/log":
      ensure => link,
      target => $log_dir,
      force  => true;
  }

  logrotate::rule { 'ui':
    path          => "${log_dir}/*.log",
    rotate        => $logrotate_ui,
    size          => '10M',
    delaycompress => true,
    copytruncate  => true,
    ifempty       => false,
    dateext       => true,
    compress      => true,
    missingok     => true,
    # su          => true,
    su_user       => $service_account,
    su_group      => $group,
    postrotate    => "kill -HUP `cat /run/puma-ui/puma.pid`", #puma
  }

  # $read_write_paths = [
  #   '/run/puma-ui', # pid, socket
  #   $log_dir,
  # ]
  #
  # $read_only_paths = [
  #   "${app_root_dir}/virtual_appliance/utils", #contains ip look up util.  or maybe its better to move it to /usr/local/bin?
  #   "${app_root_dir}/config", # contains site_config.rb
  #   "${app_dir}/current", # app lives here
  # ]

  ontoportal::puma { 'ui':
    owner            => $service_account,
    group            => $service_account,
    admin_user       => $admin_user,
    app_dir          => $app_dir,
    bundle_bin       => $bundle_bin,
    rails_env        => $environment,
    unit_environment => undef,
    read_only_paths  => $read_only_paths,
    read_write_paths => $read_write_paths,
    # puma_threads => undef,
    puma_workers     => $puma_workers,
  }
}

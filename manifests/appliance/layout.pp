class ontoportal::appliance::layout (
  Stdlib::Absolutepath $app_root_dir       = '/opt/ontoportal',
  Stdlib::Absolutepath $log_dir            = '/var/log/ontoportal',
  Stdlib::Absolutepath $data_dir           = '/srv/ontoportal',
  Stdlib::Absolutepath $tmp_dir            = '/tmp/ontoportal',

  String $admin_user         = 'ontoportal-admin',
  String $backend_user       = 'ontoportal-backend',
  String $ui_user            = 'ontoportal-ui',
  String $shared_group       = 'ontoportal-admin', # future option

  Boolean $include_ui        = false,
  Boolean $include_api       = true,
  Boolean $include_ncbo_cron = false,
) {
  # Directory layout logic here

  $dirs_base = [
    # { path => $app_root_dir, owner => $admin_user, group => $shared_group, mode => '0755' },
    { path => $app_root_dir, owner => 'root', group => 'root', mode => '0755' },
    { path => $log_dir,      owner => $admin_user, group => $shared_group, mode => '0750' },
    { path => $tmp_dir,      owner => $backend_user, group => $shared_group, mode => '0755' },
    { path => "${app_root_dir}/config", owner => $admin_user, group => $shared_group, mode => '0755' },
    { path => "${app_root_dir}/virtual_appliance", owner => $admin_user, group => $shared_group, mode => '0755' },
  ]

  $dirs_ui = $include_ui ? {
    true  => [
      # { path => "${app_root_dir}/bioportal_web_ui", owner => $ui_user, group => $shared_group, mode => '0755' },
      # { path => "${log_dir}/ui", owner => $ui_user, group => $shared_group, mode => '0755' },
    ],
    false => [],
  }

  $dirs_api = $include_api ? {
    true  => [
      { path => $data_dir,                   owner => $backend_user, group => $shared_group, mode => '0755' },
      { path => "${data_dir}/mgrep",         owner => $backend_user, group => $shared_group, mode => '0755' },
      { path => "${data_dir}/mgrep/dictionary", owner => $backend_user, group => $shared_group, mode => '0755' },
      { path => "${data_dir}/reports",       owner => $backend_user, group => $shared_group, mode => '0755' },
      # { path => "${app_root_dir}/ontologies_api", owner => $backend_user, group => $shared_group, mode => '0755' },
      # { path => "${log_dir}/ontologies_api", owner => $backend_user, group => $shared_group, mode => '0755' },
    ],
    false => [],
  }

  $dirs_cron = $include_ncbo_cron ? {
    true  => [
      { path => "${app_root_dir}/ncbo_cron", owner => $backend_user, group => $shared_group, mode => '0755' },
    ],
    false => [],
  }

  $all_dirs = $dirs_base + $dirs_ui + $dirs_api + $dirs_cron

  $all_dirs.each |$entry| {
    file { $entry['path']:
      ensure => directory,
      owner  => $entry['owner'],
      group  => $entry['group'],
      mode   => $entry['mode'],
    }
  }
}


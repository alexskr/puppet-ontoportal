class ontoportal::appliance::layout (
  Stdlib::Absolutepath $app_root_dir,
  Stdlib::Absolutepath $log_root_dir,
  Stdlib::Absolutepath $data_dir,

  String $admin_user,
  String $backend_user,
  String $ui_user,
  String $shared_group,

  Boolean $include_ui,
  Boolean $include_api,
) {
  # Directory layout logic here

  $dirs_base = [
    { path => $app_root_dir, owner => $admin_user , group => $admin_user, mode => '0755' },
    { path => $log_root_dir, owner => $admin_user, group => $shared_group, mode => '0755' },
    { path => "${app_root_dir}/config", owner => $admin_user, group => $shared_group, mode => '0755' },
    { path => "${app_root_dir}/virtual_appliance", owner => $admin_user, group => $admin_user, mode => '0755' },
    { path => "${app_root_dir}/.bundle", owner => $admin_user, group => $admin_user, mode => '0755' },
  ]

  # this is currently handled by bioportal_web_ui class
  $dirs_ui = $include_ui ? {
    true  => [
      # { path => "${app_root_dir}/bioportal_web_ui", owner => $admin_user, group => $ui_user, mode => '0750' },
      # { path => "${log_root_dir}/ui", owner => $ui_user, group => $shared_group, mode => '0755' },
    ],
    false => [],
  }

  $dirs_api = $include_api ? {
    true  => [
      { path => $data_dir,                   owner => $backend_user, group => $shared_group, mode => '0755' },
      { path => "${data_dir}/mgrep",         owner => $backend_user, group => $shared_group, mode => '0750' },
      { path => "${data_dir}/mgrep/dictionary", owner => $backend_user, group => $shared_group, mode => '2770' },
      { path => "${data_dir}/reports",       owner => $backend_user, group => $shared_group, mode => '2770' },
      # { path => "${app_root_dir}/ontologies_api", owner => $admin_user, group => $shared_group, mode => '0750' },
      # { path => "${app_root_dir}/ontologies_api/shared", owner => $admin_user, group => $admin_user, mode => '0755' },
      # { path => "${log_root_dir}/ontologies_api", owner => $backend_user, group => $shared_group, mode => '0755' },
    ],
    false => [],
  }

  $all_dirs = $dirs_base + $dirs_ui + $dirs_api

  $all_dirs.each |$entry| {
    file { $entry['path']:
      ensure => directory,
      owner  => $entry['owner'],
      group  => $entry['group'],
      mode   => $entry['mode'],
    }
  }
}

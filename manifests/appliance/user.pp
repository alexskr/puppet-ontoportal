class ontoportal::appliance::user (
  String $admin_user         = 'ontoportal-admin',
  String $backend_user       = 'ontoportal-backend',
  String $ui_user            = 'ontoportal-ui',
  String $sysadmin_user      = 'ubuntu',
  String $shared_group       = 'ontoportal-data', # this could be `ontoportal-data`
  Boolean $manage_shared_group  = true,
  Boolean $manage_admin_user    = true,
  Boolean $manage_backend_user  = true,
  Boolean $manage_ui_user       = true,
  Boolean $manage_sysadmin_user = false,

  Array[String] $admin_sshkeys    = [],
  Array[String] $sysadmin_sshkeys = [],
) {
  if $manage_shared_group {
    group { $shared_group:
      ensure => present,
    }
    $_shared_group = $shared_group
    $_backend_user_group = $hared_group
  } else {
    $_shared_group = undef
    $_backend_user_group = $backend_user
  }

  if $manage_admin_user {
    class { 'ontoportal::user::admin':
      user         => $admin_user,
      shared_group => $_shared_group,
      sshkeys      => $admin_sshkeys,
    }
  }

  if $manage_backend_user {
    class { 'ontoportal::user::backend':
      user  => $backend_user,
      group => $_backend_user_group,
    }
  }

  if $manage_ui_user {
    class { 'ontoportal::user::ui':
      user => $ui_user,
    }
  }

  if $manage_sysadmin_user {
    class { 'ontoportal::user::sysadmin':
      user         => $sysadmin_user,
      sshkeys      => $sysadmin_sshkeys,
    }
  }
}

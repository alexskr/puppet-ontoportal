class ontoportal::appliance::user (
  String $admin_user,
  String $backend_user,
  String $ui_user,
  String $sysadmin_user,
  String $shared_group,
  Boolean $manage_admin_user    = true,
  Boolean $manage_backend_user  = true,
  Boolean $manage_ui_user       = true,
  Boolean $manage_sysadmin_user = false,

  Array[String] $admin_sshkeys    = [],
  Array[String] $sysadmin_sshkeys = [],
) {
  if $manage_admin_user {
    class { 'ontoportal::user::admin':
      user    => $admin_user,
      groups  => [$shared_group, $ui_user],
      sshkeys => $admin_sshkeys,
    }
  }

  if $manage_backend_user {
    class { 'ontoportal::user::backend':
      user  => $backend_user,
      group => $shared_group,
    }
  }

  if $manage_ui_user {
    class { 'ontoportal::user::ui':
      user => $ui_user,
    }
  }

  if $manage_sysadmin_user {
    class { 'ontoportal::user::sysadmin':
      user    => $sysadmin_user,
      sshkeys => $sysadmin_sshkeys,
    }
  }
}

class ontoportal::appliance::user (
  String $admin_user         = 'ontoportal-admin',
  String $backend_user       = 'ontoportal-backend',
  String $ui_user            = 'ontoportal-ui',
  String $sysadmin_user      = 'ubuntu',
  String $shared_group       = 'ontoportal',

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
      ensure =>  present,
    }
  }

  if $manage_admin_user {
    class { 'ontoportal::user::admin':
      user         => $admin_user,
      shared_group => $shared_group,
      sshkeys      => $admin_sshkeys,
    }
  }

  if $manage_backend_user {
    class { 'ontoportal::user::backend':
      user         => $backend_user,
      # shared_group => $shared_group,
    }
  }

  if $manage_ui_user {
    class { 'ontoportal::user::ui':
      user         => $ui_user,
      # shared_group => $shared_group,
    }
  }

  if $manage_sysadmin_user {
    class { 'ontoportal::user::sysadmin':
      user         => $sysadmin_user,
      shared_group => $shared_group,
      sshkeys      => $sysadmin_sshkeys,
    }
  }
}


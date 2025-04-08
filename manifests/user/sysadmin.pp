class ontoportal::user::sysadmin (
  String              $user      = 'ubuntu',
  Array[String]       $ssh_keys = [],
  String              $shell     = '/bin/bash',
  String              $comment   = 'System SSH user with sudo access',
  Boolean             $managehome = true,
) {
  accounts::user { $user:
    ensure      => present,
    comment     => $comment,
    shell       => $shell,
    home        => "/home/${user}",
    managehome  => $managehome,
    ssh_keys    => $ssh_keys,
  }
  sudo::conf { $user:
    comment =>  "sysadmin user for ontoportal appliance",
    content => "${user} ALL=(ALL) NOPASSWD: ALL",
  }
}

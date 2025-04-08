class ontoportal::user::sysadmin (
  String              $user      = 'ubuntu',
  Array[String]       $sshkeys = [],
  String              $shell     = '/bin/bash',
  String              $comment   = 'System SSH user with sudo access',
  Boolean             $managehome = true,
) {
  accounts::user { $user:
    ensure     => present,
    comment    => $comment,
    shell      => $shell,
    home       => "/home/${user}",
    managehome => $managehome,
    sshkeys    => $sshkeys,
  }
  sudo::conf { $user:
    content => "${user} ALL=(ALL) NOPASSWD: ALL",
  }
}

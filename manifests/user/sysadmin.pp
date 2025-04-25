class ontoportal::user::sysadmin (
  String           $user       = 'ubuntu',
  Array[String]    $sshkeys    = [],
  String           $shell      = '/bin/bash',
  String           $comment    = 'OntoPortal SysAdmin user',
  Optional[String] $password   = undef,
  Boolean          $managehome = true,
) {
  accounts::user { $user:
    ensure     => present,
    comment    => $comment,
    shell      => $shell,
    home       => "/home/${user}",
    password   => $_password,
    managehome => $managehome,
    sshkeys    => $sshkeys,
  }
  sudo::conf { $user:
    content => "${user} ALL=(ALL) NOPASSWD: ALL",
  }
}

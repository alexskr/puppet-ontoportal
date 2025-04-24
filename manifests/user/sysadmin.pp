class ontoportal::user::sysadmin (
  String           $user       = 'ubuntu',
  Array[String]    $sshkeys    = [],
  String           $shell      = '/bin/bash',
  String           $comment    = 'OntoPortal SysAdmin user',
  Optional[String] $password   = undef,
  Boolean          $managehome = true,
) {
  # don't set password for ubuntu user in ami
  $_password = $facts['ec2_metadata'] ? {
    undef   => $password, # not on AWS
    default => undef,     # on AWS, disable password
  }

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

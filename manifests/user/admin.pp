class ontoportal::user::admin (
  String        $user         = 'ontoportal-admin',
  String        $shared_group = 'ontoportal',
  String        $shell        = '/bin/bash',
  String        $home         = "/home/${user}",
  Boolean       $managehome   = true,
  Array[String] $sshkeys      = [],
) {
  accounts::user { $user:
    ensure     => present,
    comment    => 'Application Admin/OPS/deployment user',
    shell      => $shell,
    home       => $home,
    managehome => $managehome,
    group      => $user,
    groups     => [
      $shared_group,
    ],
    sshkeys    => $sshkeys,
  }

  # do we need this?
  file { "/home/${user}.gemrc":
    owner   => $user,
    mode    => '0644',
    content => 'install: --no-document',
    require => User[$user],
  }
  file_line { 'ontoportal ruby gem path':
    path    => "${home}/.bashrc",
    line    => 'which ruby >/dev/null && which gem >/dev/null && PATH="$(ruby -r rubygems -e \'puts Gem.user_dir\')/bin:$PATH"',
    require => User[$user],
  }
}

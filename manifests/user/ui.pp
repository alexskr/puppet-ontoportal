class ontoportal::user::ui (
  String $user = 'ontoportal-ui',
) {
  group { $user:
    ensure => present,
  }

  user { $user:
    ensure     => present,
    comment    => "service account for puma-ui",
    system     => true,
    shell      => '/usr/sbin/nologin',
    managehome => false,
    home       => '/nonexistent',
    gid        => $user,
  }
}

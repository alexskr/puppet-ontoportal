class ontoportal::user::ui (
  String $user = 'op-ui',
) {
  group { $user:
    ensure => present,
  }

  user { $user:
    ensure     => present,
    comment    => 'Service Account for puma-ui',
    system     => true,
    shell      => '/usr/sbin/nologin',
    managehome => false,
    home       => '/nonexistent',
    gid        => $user,
  }
}

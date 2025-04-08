class ontoportal::user::backend (
  String $user  = 'ontoportal-backend',
  String $group = 'ontoportal-backend',
  String $home  = '/nonexistent',
) {
  group { $group:
    ensure => present,
  }

  user { $user:
    ensure     => present,
    comment    => 'service account for API and ncbo_cron',
    system     => true,
    shell      => '/usr/sbin/nologin',
    home       => '/nonexistent',
    managehome => false,
    gid        => $group,
  }
}

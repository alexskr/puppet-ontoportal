class ontoportal::user::backend (
  String $user  = 'op-backend',
  String $group = 'opdata',
  Optional[Integer] $uid = undef,
  Optional[Integer] $gid = undef,
  String $home  = '/nonexistent',
) {
  # create shared data group
  group { $group:
    ensure => present,
    gid    => $gid,
  }

  user { $user:
    ensure     => present,
    comment    => 'service account for API and ncbo_cron',
    system     => true,
    uid        => $uid,
    shell      => '/usr/sbin/nologin',
    home       => '/nonexistent',
    managehome => false,
    gid        => $group,
  }
}

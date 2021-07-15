#
# Class: ncbo::mgrep
#
# Description: This class manages mgrep nodes
# one of which is master which controlls rolling restart
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class profile::ncbo::mgrep(
  String $environment   = 'staging',
  Boolean $mgrep_master = false,
  $mgrep_redishost,
  ) {
  include profile::base
  include profile::ncbo::base
  class { 'mgrep':
    dict_symlink  => "/srv/ncbo/share/env/${environment}/mgrep/dictionary.txt",
    mgrep_enable  => true
  }
  -> class { 'mgrep::rrestart':
    mgrep_master    => $mgrep_master,
    mgrep_redishost => $mgrep_redishost,
  }
}


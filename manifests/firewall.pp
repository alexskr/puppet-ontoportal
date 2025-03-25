#
# Class:  firewall
#
# Description: This class manages standard firewall rules for BMIR, and works
#              for CentOS/EL. All classes ordered by firewall policy number,
#              which is loosely based on TCP/UDP port number. Firewall policy
#              numbering scheme is designed to spread out policy numbers between
#              0 and 999 - while allowing plenty of space to grow. The goal is
#              to never have to renumber the policies again.
#                
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class ontoportal::firewall (
  Optional[Hash[String, Hash]] $multis = {},
) {
  require firewall

  resources { 'firewall':
    purge => true,
  }

  resources { 'firewallchain':
    purge => true,
  }

  Firewall {
    before  => Class['ontoportal::firewall::post'],
    require => Class['ontoportal::firewall::pre'],
  }

  class { ['ontoportal::firewall::pre','ontoportal::firewall::post']: }

  # Pull in firewall rules from hiera.
  if $multis {
    $multis.each | $name, $firewall_multi | {
      firewall_multi { $name:
        * => $firewall_multi,
      }
    }
  }
}

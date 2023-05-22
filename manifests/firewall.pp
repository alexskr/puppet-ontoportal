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

class ontoportal::firewall(
  Optional[Hash[String, Hash]] $multis = {},
){

  include firewall

  # Add ability not to purge unmanaged rules that could be creatd by docker or f2b
  # https://tickets.puppetlabs.com/browse/MODULES-2314

  # first we set firewall purging to false overall
  resources { 'firewall':
    purge => false,
  }
  resources { 'firewallchain':
    purge => false,
  }
  # Then we set specific firewall chains to purge (all default tables):
  firewallchain {
    ['INPUT:filter:IPv4',
      'FORWARD:filter:IPv4',
      'OUTPUT:filter:IPv4',
      'PREROUTING:mangle:IPv4',
      'INPUT:mangle:IPv4',
      'FORWARD:mangle:IPv4',
      'OUTPUT:mangle:IPv4',
      'POSTROUTING:mangle:IPv4',
      'PREROUTING:nat:IPv4',
      'INPUT:nat:IPv4',
      'OUTPUT:nat:IPv4',
      'POSTROUTING:nat:IPv4']:
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

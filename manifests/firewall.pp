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
  [ 'INPUT:filter:IPv4',
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
    purge => true
  }

  # Finally we would overwrite the behaviour to ignore specific rules:
  # module 'docker'
  Firewallchain <| title == 'PREROUTING:nat:IPv4' |> {
    ignore +> [ '-j DOCKER' ]
  }

  # or we could add overwrites in modules:

# # module 'kubernetes'
# Firewallchain <| title == 'PREROUTING:nat:IPv4' |> {
#    ignore +> [ '-j KUBE' ]
# }
#

  Firewall {
      before  => Class['ontoportal::firewall::post'],
      require => Class['ontoportal::firewall::pre'],
  }

  class { ['ontoportal::firewall::pre','ontoportal::firewall::post']: }

  # Pull in firewall rules from hiera.
  if $multis {
  $multis.each |$name, $firewall_multi| {
    firewall_multi { $name:
      * => $firewall_multi
    }
  }
  }
  #create_resources('firewall', hiera_hash('firewall_rules', {}))
  #create_resources('firewall_multi', hiera_hash('firewall_multis', {}))

}

class ontoportal::firewall::pre {

  Firewall {
    require => undef,
  }

  # Default ipv4 firewall rules
  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  }
  -> firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }
  -> firewall { '002 reject local traffic not on loopback interface':
    iniface     => '! lo',
    proto       => 'all',
    destination => '127.0.0.1/8',
    action      => 'reject',
  }
  -> firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  }

  # Default ipv6 firewall rules. We are dropping pretty much everything here.
  firewall { '000 accept all icmp (ipv6)':
    proto    => 'ipv6-icmp',
    action   => 'accept',
    provider => 'ip6tables',
  }
  -> firewall { '001 accept all to lo interface (ipv6)':
    proto    => 'all',
    iniface  => 'lo',
    action   => 'accept',
    provider => 'ip6tables',
  }
  #-> firewall { '002 reject local traffic not on loopback interface (ipv6)':
  #  iniface     => '! lo',
  #  proto       => 'all',
  #  destination => '127.0.0.1/8',
  #  action      => 'reject',
  #  provider => 'ip6tables',
  #}
  -> firewall { '003 accept related established rules (ipv6)':
    proto    => 'all',
    state    => ['RELATED', 'ESTABLISHED'],
    action   => 'accept',
    provider => 'ip6tables',
  }

}

class ontoportal::firewall::ssh {

  firewall_multi { '020 Allow inbound SSH':
    dport  => '22',
    proto  => 'tcp',
    action => 'accept',
  }

}

class ontoportal::firewall::http {

  firewall_multi { '040 Allow inbound HTTP':
    dport    => [80, 443],
    proto    => 'tcp',
    action   => 'accept',
    provider => ['ip6tables', 'iptables'],
  }

}

class ontoportal::firewall::p8080 {

  firewall_multi { '110 Allow inbound 8080':
    dport  => '8080',
    proto  => 'tcp',
    action => 'accept',
  }

}

class ontoportal::firewall::post {

  firewall { '999 drop all':
    proto  => 'all',
    action => 'drop',
    before => undef,
  }

  firewall { '999 drop all (ipv6)':
    proto    => 'all',
    action   => 'drop',
    before   => undef,
    provider => 'ip6tables',
  }

}


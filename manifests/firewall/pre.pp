class ontoportal::firewall::pre {

  Firewall {
    require => undef,
  }

  # Default ipv4 firewall rules
  firewall { '000 accept all icmp':
    proto => 'icmp',
    jump  => 'accept',
  }
  -> firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    jump    => 'accept',
  }
  -> firewall { '002 reject local traffic not on loopback interface':
    iniface     => '! lo',
    proto       => 'all',
    destination => '127.0.0.1/8',
    jump        => 'reject',
  }
  -> firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    jump   => 'accept',
  }

  # Default ipv6 firewall rules. We are dropping pretty much everything here.
  firewall { '000 accept all icmp (ipv6)':
    proto    => 'ipv6-icmp',
    jump     => 'accept',
    protocol => 'ip6tables',
  }
  -> firewall { '001 accept all to lo interface (ipv6)':
    proto    => 'all',
    iniface  => 'lo',
    jump     => 'accept',
    protocol => 'ip6tables',
  }
  -> firewall { '003 accept related established rules (ipv6)':
    proto    => 'all',
    state    => ['RELATED', 'ESTABLISHED'],
    jump     => 'accept',
    protocol => 'ip6tables',
  }

}

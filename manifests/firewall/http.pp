class ontoportal::firewall::http {
  firewall_multi { '040 Allow inbound HTTP':
    dport    => [80, 443],
    proto    => 'tcp',
    jump     => 'accept',
    protocol => ['ip6tables', 'iptables'],
  }
}

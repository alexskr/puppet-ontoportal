class ontoportal::firewall::http {
  firewall_multi { '040 Allow inbound HTTP':
    dport    => [80, 443],
    proto    => 'tcp',
    action   => 'accept',
    provider => ['ip6tables', 'iptables'],
  }
}

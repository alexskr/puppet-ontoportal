class ontoportal::firewall::ssh {
  firewall_multi { '020 Allow inbound SSH':
    dport => '22',
    proto => 'tcp',
    jump  => 'accept',
  }
}

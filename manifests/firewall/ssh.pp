class ontoportal::firewall::ssh {
  include ontoportal::firewall
  firewall_multi { '020 Allow inbound SSH':
    dport => '22',
    proto => 'tcp',
    jump  => 'accept',
  }
}

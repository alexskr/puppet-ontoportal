class ontoportal::firewall::api {
  include ontoportal::firewall
  firewall_multi { '110 Allow inbound rest api':
    dport => ['8080','8443'],
    proto => 'tcp',
    jump  => 'accept',
  }
}

class ontoportal::appliance::cleanup {

  file { [
    '/usr/local/bin/oprestart',
    '/usr/local/bin/opstop',
    '/usr/local/bin/opstart',
    '/usr/local/bin/opstatus',
    '/usr/local/bin/opclearcaches',
  ]:
    ensure => absent,
  }

  user { 'ontoportal':
    ensure => absent,
    managehome => true,
  }

}

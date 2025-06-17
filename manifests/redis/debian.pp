class ontoportal::redis::debian {
  class { 'redis':
    default_install => false,
    service_enable  => false,
    service_ensure  => 'stopped',
    log_dir         => '/var/log/redis',
  }
}

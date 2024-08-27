#this profile class is written for arioch/puppet-redis which is a bit quircky

class ontoportal::redis(
  Boolean $optimize_kernel = true,
) {
  case $facts['os']['family'] {
    'RedHat': { include ontoportal::redis::redhat }
    'Debian': { include ontoportal::redis::debian }
  }

  # https://redis.io/topics/admin
  if  $optimize_kernel {
    include redis::administration
    kernel_parameter { 'transparent_hugepage':
      ensure => present,
      value  => 'never',
    }
  }
}

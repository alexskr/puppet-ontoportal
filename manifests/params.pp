class ontoportal::params (
) {
  case $facts['os']['family'] {
    'RedHat': {
      if ($facts['os']['release']['major'] != '7') {
        fail ('this module doesnt support this platform')
      }
      require epel
      $pkg_mariadb_dev = 'mariadb-devel'
      $pkg_libxml2_dev = 'libxml2-devel'
      $pkg_libwww_perl = 'perl-libwww-perl'
      $java_package = 'java-11-openjdk'
    }
    'Debian': {
      $pkg_mariadb_dev = 'libmariadb-dev'
      $pkg_libxml2_dev = 'libxml2-dev'
      $pkg_libwww_perl = 'libwww-perl'
      $java_package = 'openjdk-11-jre'
    }
    default: { fail('unsupported platform') }
  }
}

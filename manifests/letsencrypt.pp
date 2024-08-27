#letsencrypt wrapper
define ontoportal::letsencrypt(
  Stdlib::Fqdn $domain                = $name,
  Enum['webroot', 'apache', 'nginx'] $plugin = 'webroot',
  Stdlib::Absolutepath $webroot_paths = ['/mnt/.letsencrypt'],
  String $cron_success_command        = '/bin/systemctl reload httpd.service',
  $san                                = [], #subject alternate names
) {
  include letsencrypt
  include cron

  case $facts['os']['family'] {
    'Debian': {
      $apache_service_name = 'apache2.service'
      $apache_certbot_plugin_pkg = 'python3-certbot-apache'
    }
    'RedHat': {
      $apache_service_name = 'httpd.service'
      $apache_certbot_plugin_pkg = 'python2-certbot-apache'
    }
  }

  if $plugin == 'apache' {
    ensure_packages ( $apache_certbot_plugin_pkg )
  }

  if $cron_success_command == undef {
    case $plugin {
      'apache': { $_cron_success_command = "/bin/systemctl reload ${apache_service_name}" }
      'nginx': { $_cron_success_command = '/bin/systemctl reload nginx.service' }
    }
  } else {
    $_cron_success_command = $cron_success_command
  }

  $_domains = concat ( [$domain], $san )
  letsencrypt::certonly { $domain:
    domains              => $_domains,
    webroot_paths        => $webroot_paths,
    plugin               => $plugin,
    manage_cron          => true,
    cron_success_command => $_cron_success_command,
  }
}

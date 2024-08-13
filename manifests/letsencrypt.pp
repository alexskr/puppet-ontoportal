#letsencrypt wrapper...

define ontoportal::letsencrypt(
  $domain               = $name,
  Enum['webroot', 'apache', 'nginx'] $plugin = 'webroot',
  $webroot_paths         = [ '/mnt/.letsencrypt' ],
  $cron_success_command = '/bin/systemctl reload httpd.service',
  $san                  = [], #subject alternate names
  ){
  if $plugin == 'apache' {
    ensure_packages ('python2-certbot-apache')
  }
  if $plugin == 'nginx' {
    ensure_packages ('certbot-nginx')
  }
  include letsencrypt
  #class { 'letsencrypt': }
  $_domains = concat ( [$domain], $san )
  letsencrypt::certonly { $domain:
      domains              => $_domains,
      webroot_paths        => $webroot_paths,
      plugin               => $plugin,
      manage_cron          => true,
      cron_success_command =>  $cron_success_command,
  }
}

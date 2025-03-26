#letsencrypt wrapper for nginx

define profile::web::letsencrypt::nginx(
  $domain = $name,
  $san    = [], #subject alternate names
  ){
  include letsencrypt
  include letsencrypt::plugin::nginx

  $_domains = concat ( [$domain], $san )
  letsencrypt::certonly { $domain:
      domains              => $_domains,
      plugin               => 'nginx',
      manage_cron          => true,
      environment          => ['PATH=/usr/sbin:/usr/bin:/sbin:/bin'], #see https://github.com/voxpupuli/puppet-letsencrypt/issues/250
      cron_success_command => '/bin/systemctl reload nginx.service',
  }

}

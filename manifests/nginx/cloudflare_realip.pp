class ontoportal::nginx::cloudflare_realip (
  $ensure = 'present',
){

  # realip nginx extention comes in nginx-extras
  ensure_packages(['nginx-extras'])

  file { '/usr/local/bin/update_cloudflare_ips.sh':
      ensure => 'present',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/ontoportal/nginx_cloudflare_realip.sh'
  }

  # Add weekly cron job to update Cloudflare IPs
  cron { 'update_cloudflare_real_ip':
    ensure  => $ensure,
    command => "/usr/local/bin/update_cloudflare_ips.sh",
    user    => 'root',
    weekday => '1',  # Runs every Monday
    hour    => '0',
    minute  => '0',
  }
}

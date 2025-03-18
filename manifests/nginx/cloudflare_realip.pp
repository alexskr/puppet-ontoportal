class ontoportal::nginx::cloudflare_realip (
  $ensure = 'present',
){

  # realip nginx extention comes in nginx-extras
  ensure_packages(['nginx-extras'])

  file { '/etc/nginx/conf.d/cloudflare_real_ip.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/ontoportal/nginx-cloudflare_real_ip.conf',
    replace => false, #rely on the cronjob to get latest updates"
  }

  file { '/usr/local/bin/nginx-cloudflare_real_ip.sh':
      ensure => 'present',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/ontoportal/nginx-cloudflare_real_ip-cron.sh'
  }

  # Add weekly cron job to update Cloudflare IPs
  cron { 'update_cloudflare_real_ip':
    ensure  => $ensure,
    command => "/usr/local/bin/nginx-cloudflare_real_ip.sh",
    user    => 'root',
    weekday => '1',  # Runs every Monday
    hour    => '0',
    minute  => '0',
  }
}

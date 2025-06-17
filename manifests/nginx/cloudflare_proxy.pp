class ontoportal::nginx::cloudflare_proxy (
  Enum['present', 'absent'] $ensure = 'present',
  Boolean $block_non_cloudflare = false,
) {
  # realip nginx extention required for this to work comes in nginx-extras
  stdlib::ensure_packages (['nginx-extras'])

  file { '/etc/nginx/conf.d/cloudflare_real_ip.conf':
    ensure  => $ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/ontoportal/etc/nginx/conf.d/cloudflare_real_ip.conf',
    replace => false, #rely on the cronjob to get latest updates"
  }

  if $block_non_cloudflare {
    file { '/etc/nginx/conf.d/cloudflare_proxy_ip_restrict.conf':
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => 'puppet:///modules/ontoportal/etc/nginx/conf.d/cloudflare_proxy_ip_restrict.conf',
      replace => false, #rely on the cronjob to get latest updates"
    }
  }
  file { '/usr/local/bin/nginx-cloudflare_proxy_config.sh':
    ensure => $ensure,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/ontoportal/nginx-cloudflare_proxy_config-cron.sh',
  }

  # Add weekly cron job to update Cloudflare IPs
  cron::job { 'update_cloudflare_proxy_config':
    ensure  => $ensure,
    command => "/usr/local/bin/nginx-cloudflare_proxy_config.sh ${block_non_cloudflare}",
    minute  => '0',
    hour    => '*/1',
    user    => 'root',
  }
}

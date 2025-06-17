# @summary Manages Cloudflare proxy configuration for Nginx
#
# This class configures Nginx to properly handle Cloudflare proxy connections by:
# - Setting up real IP detection from Cloudflare headers
# - Optionally restricting access to only Cloudflare IPs
# - Automatically updating Cloudflare IP ranges
#
# @param ensure
#   Whether to ensure the Cloudflare proxy configuration is present or absent
# @param block_non_cloudflare
#   Whether to enable proxy restriction for Cloudflare IPs. When enabled, only requests
#   from Cloudflare IPs will be accepted, providing an additional security layer.
#
class ontoportal::nginx::cloudflare_proxy (
  Enum['present', 'absent'] $ensure = 'present',
  Boolean $block_non_cloudflare     = false,
) {
  # realip nginx extention required for this to work comes in nginx-extras
  stdlib::ensure_packages (['nginx-extras'])

  file { '/etc/nginx/conf.d/cloudflare_real_ip.conf':
    ensure  => $ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/ontoportal/nginx-cloudflare_real_ip.conf',
    replace => false, #rely on the cronjob to get latest updates"
  }

  if $block_non_cloudflare {
    file { '/usr/local/bin/nginx-cloudflare_proxy_restrict.sh':
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => 'puppet:///modules/ontoportal/nginx-cloudflare_proxy_restrict.conf',
      replace => false, #rely on the cronjob to get latest updates"
    }
  }
  file { '/usr/local/bin/nginx-cloudflare_real_ip.sh':
    ensure => $ensure,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/ontoportal/nginx-cloudflare_real_ip-cron.sh',
  }

  # Add weekly cron job to update Cloudflare IPs
  cron::job { 'update_cloudflare_ips':
    ensure  => $ensure,
    command => "/path/to/cloudflare_proxy_config.sh ${block_non_cloudflare}",
    minute  => '0',
    hour    => '*/1',
    user    => 'root',
  }
}

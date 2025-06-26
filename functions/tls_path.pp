# Return the correct TLS file path for a domain.
#
#   ontoportal::tls_path($domain)                → fullchain path
#   ontoportal::tls_path($domain, 'key')         → privkey path
#   ontoportal::tls_path($domain, 'cert', '/path/to/alt.pem') → override
#
function ontoportal::tls_path(
  Stdlib::Fqdn                   $domain,
  Enum['cert','key']             $kind     = 'cert',
  Optional[Stdlib::Absolutepath] $override = undef,
) >> String {
  # 1. explicit override wins
  if $override {
    return $override
  }

  # 2. LetsEncrypt fact path (if cert already issued)
  $le_dir = $facts.dig('letsencrypt_directory', $domain)

  if $le_dir {
    return $kind ? {
      'cert' => "${le_dir}/fullchain.pem",
      'key'  => "${le_dir}/privkey.pem",
    }
  }

  # 3. fallback to system snake-oil
  return $kind ? {
    'cert' => '/etc/ssl/certs/ssl-cert-snakeoil.pem',
    'key'  => '/etc/ssl/private/ssl-cert-snakeoil.key',
  }
}

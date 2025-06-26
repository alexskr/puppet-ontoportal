# Return both TLS certificate and key paths for a domain.
#
#   ontoportal::tls_paths($domain)                                    -> returns hash with 'cert' and 'key' paths
#   ontoportal::tls_paths($domain, '/path/to/cert.pem', '/path/to/key.pem')  -> uses custom paths
#
function ontoportal::tls_paths(
  Stdlib::Fqdn                   $domain,
  Optional[Stdlib::Absolutepath] $override_cert = undef,
  Optional[Stdlib::Absolutepath] $override_key  = undef,
) >> Hash {
  # 1. explicit override wins
  if $override_cert or $override_key {
    $cert_path = $override_cert ? {
      Undef   => '/etc/ssl/certs/ssl-cert-snakeoil.pem',
      default => $override_cert
    }
    $key_path = $override_key ? {
      Undef   => '/etc/ssl/private/ssl-cert-snakeoil.key',
      default => $override_key
    }
  } else {
    # 2. LetsEncrypt fact path (if cert already issued)
    $le_dir = $facts.dig('letsencrypt_directory', $domain)

    if $le_dir {
      $cert_path = "${le_dir}/fullchain.pem"
      $key_path = "${le_dir}/privkey.pem"
    } else {
      # 3. fallback to system snake-oil
      $cert_path = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
      $key_path = '/etc/ssl/private/ssl-cert-snakeoil.key'
    }
  }

  $result = {
    'cert' => $cert_path,
    'key'  => $key_path
  }
  return $result
} 

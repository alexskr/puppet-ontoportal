# @summary Manages the Let's Encrypt webroot directory for domain validation
#
# This class ensures the webroot directory exists and has proper permissions.
# It is included by the ontoportal::nginx::letsencrypt defined type when using
# webroot authentication, but can also be included directly if needed.
#
# @param webroot_path
#   The path where Let's Encrypt will place temporary files for domain validation.
#
class ontoportal::nginx::letsencrypt::webroot (
  Stdlib::Absolutepath $webroot_path = '/var/lib/letsencrypt/webroot',
) {
  file { $webroot_path:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
}

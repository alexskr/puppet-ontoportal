# @summary Manages Let's Encrypt certificates for OntoPortal NGINX servers
#
# @example Using with NGINX plugin (default)
#   ontoportal::nginx::letsencrypt { 'demo.ontoportal.org':
#     san => ['umls.demo.ontoportal.org'],
#   }
#
# @example Using with webroot authentication
#   ontoportal::nginx::letsencrypt { 'demo.ontoportal.org':
#     plugin => 'webroot',
#     san => ['umls.demo.ontoportal.org'],
#   }
#
# @param domain
#   The primary domain name for the certificate. Defaults to the resource title.
#
# @param plugin
#   The Let's Encrypt authentication plugin to use. Valid options:
#   - 'nginx': Uses the nginx plugin for domain validation (default)
#   - 'webroot': Uses webroot authentication method, useful for load balanced environments
#
# @param webroot_paths
#   The path where Let's Encrypt will place temporary files for domain validation
#   when using the webroot plugin. Defaults to '/var/lib/letsencrypt/webroot'.
#   Only used when plugin => 'webroot'.
#
# @param cron_success_command
#   Command to run after successful certificate renewal. Defaults to reloading NGINX.
#
# @param san
#   Array of Subject Alternative Names (SANs) to include in the certificate.
#   These are additional domain names that will be protected by the same certificate.
#   Useful for ontoportal slices.
#
define ontoportal::nginx::letsencrypt (
  Stdlib::Fqdn $domain             = $name,
  Enum['webroot', 'nginx'] $plugin = 'nginx',
  Array[Stdlib::Absolutepath] $webroot_paths = ['/var/lib/letsencrypt/webroot'],
  String $cron_success_command     = '/usr/bin/systemctl reload nginx.service',
  Array[Stdlib::Fqdn] $san         = [],
) {
  include letsencrypt
  include cron

  if $plugin == 'webroot' {
    include ontoportal::nginx::letsencrypt::webroot
  } else {
    include letsencrypt::plugin::nginx
  }

  $_domains = concat([$domain], $san)

  letsencrypt::certonly { $domain:
    domains              => $_domains,
    webroot_paths        => $webroot_paths,
    plugin               => $plugin,
    manage_cron          => true,
    cron_success_command => $cron_success_command,
  }
}

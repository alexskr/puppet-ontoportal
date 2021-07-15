#
# Class: ncbo::profile::biomixer
#
# Description: This class manages biomixer reverse proxy
# actuall app runs on tomcat
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

class profile::ncbo::biomixer (
  $owner             = 'ncbo-deployer',
  $group             = 'ncbo',
  $enable_mod_status = true,
  $logrotate_httpd   = 400,
  $domain = 'biomixer.bioontology.org',
  $ssl_cert = "/etc/letsencrypt/live/$domain/cert.pem",
  $ssl_key = "/etc/letsencrypt/live/$domain/privkey.pem",
  $ssl_chain = "/etc/letsencrypt/live/$domain/chain.pem",
  ){
  include profile::firewall::http
  include profile::firewall::p8080_bmirvlan
  class { 'profile::tomcat':
  }


  profile::ncbo::letsencrypt { "$domain":
    domain => $domain,
    plugin => 'apache',
  }
  class { 'apache':
      default_vhost    => false,
      manage_user      => false,
      manage_group     => false,
      trace_enable     => false,
      server_signature => false,
      default_mods     => false,
      mpm_module       => 'worker',
  }
  apache::listen { '80': }
  apache::listen { '443': }
  class { 'apache::mod::headers': }
  class { 'apache::mod::ssl': }
  #class { 'apache::mod::xsendfile': }
  class { 'apache::mod::rewrite': }
  class { 'apache::mod::deflate': }
  class { 'apache::mod::expires': }
  class { 'apache::mod::dir': }

  if str2bool ( $enable_mod_status ) {
    class { 'apache::mod::status':
      allow_from => [ '127.0.0.1', '171.65.32.0/23', '171.66.16.0/20' ]
    }
  }

  #disable rbenv refreshing apache.  it keeps on triggering even when rbenv hasn't changed.
  #Class['profile::ncbo::rbenv'] ~> Class['apache']


  #site
  $_docroot = "/var/www/html"
  $alias_le = { alias => '/.well-known/acme-challenge/',
                path  => '/mnt/.letsencrypt/.well-known/acme-challenge/'}
  $directories_le = {
    path              => '/mnt/.letsencrypt/.well-known/acme-challenge',
    require           => 'all granted',
    #options          => 'MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec',
    # Require method GET POST OPTIONS
    allow_override    => 'None',
  }

  apache::vhost { "${domain}_non-tls":
      servername            => $domain,
      # serveraliases         => $serveraliases,
      port                  => '80',
      default_vhost         => true,
      docroot               => $_docroot,
      manage_docroot        => false,
      #aliases              => $_aliases,
      aliases               => $alias_le,
      directories           => $directories_le,
      proxy_pass => [
          { 'path' =>'/',
            'url' => 'http://localhost:8080/biomixer/',
            'reverse_urls'  => ['http://localhost:8080/biomixer/'],
            'params'        => {'timeout' =>1200},
            'no_proxy_uris' => ['/.well-known/acme-challenge/'], }
      ],
  }

  apache::vhost { "${domain}_tls":
    servername      => $domain,
    # serveraliases   => $serveraliases,
    port            => '443',
    default_vhost   => true,
    ssl             => true,
    ssl_cert        => $ssl_cert,
    ssl_key         => $ssl_key,
    ssl_chain       => $ssl_chain,
    docroot         => $_docroot,
    manage_docroot  => false,
    aliases         => $alias_le,
    allow_encoded_slashes =>  'nodecode',
      proxy_pass => [
          { 'path' =>'/', 'url' => 'http://localhost:8080/biomixer/',
            'reverse_urls' => ['http://localhost:8080/biomixer/'],
            'params' => {'timeout' =>1200}}
      ],
  }

  logrotate::rule { 'httpd':
    path       => '/var/log/httpd/*log',
    rotate     => $logrotate_httpd,
    size       => '10M',
    dateext    => true,
    compress   => true,
    missingok  => true,
    postrotate => '/sbin/service httpd reload > /dev/null 2>/dev/null || true',
  }

}



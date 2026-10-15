# @summary Serves Let's Encrypt HTTP-01 challenges for an NGINX server
#
# Challenge files are served from a local webroot. When peers are given, a
# token that is not on local disk is fetched from the peers instead, so any
# node behind a load balancer can answer validation for a certificate that
# another node is requesting. A forwarded request is never forwarded again.
#
# @example Two load balanced UI nodes
#   ontoportal::nginx::acme_challenge { 'ontoportal_web_ui':
#     peers => ['ui-01.example.org', 'ui-02.example.org'],
#   }
#
# @param server
#   The nginx::resource::server to add the challenge location to.
#
# @param webroot
#   Local directory certbot's webroot plugin writes challenge files to.
#
# @param peers
#   Other members of the load balanced pool. This node is dropped from the
#   list by hostname, so the same list can be used on every member. The peer
#   upstream is shared by all servers on a node, so every instance on a node
#   must be given the same list.
#
define ontoportal::nginx::acme_challenge (
  String[1] $server                = $name,
  Stdlib::Absolutepath $webroot    = '/var/lib/letsencrypt/webroot',
  Array[Stdlib::Host] $peers       = [],
) {
  $_peers = $peers.filter |$peer| { $peer.split('\.')[0] != $facts['networking']['hostname'] }

  nginx::resource::location { "acme-challenge-${server}":
    ensure              => present,
    server              => $server,
    ssl                 => false,
    location            => '^~ /.well-known/acme-challenge/',
    www_root            => $webroot,
    index_files         => [],
    try_files           => empty($_peers) ? {
      true  => undef,
      false => ['$uri', '@acme_peers'],
    },
    location_cfg_append => {
      'default_type' => 'text/plain',
    },
  }

  unless empty($_peers) {
    ensure_resource('nginx::resource::upstream', 'acme_peers', {
      'members' => $_peers.reduce({}) |$memo, $peer| { $memo + { $peer => { 'server' => $peer, 'port' => 80 } } },
    })

    nginx::resource::location { "acme-peers-${server}":
      ensure                => present,
      server                => $server,
      location              => '@acme_peers',
      ssl                   => false,
      index_files           => [],
      raw_prepend           => 'if ($http_x_acme_forwarded) { return 404; }',
      proxy                 => 'http://acme_peers',
      proxy_set_header      => ['Host $host', 'X-Acme-Forwarded 1'],
      proxy_next_upstream   => 'error timeout http_404',
      # a dead peer must not stall validation, the CA gives up long before 90s
      proxy_connect_timeout => '3s',
      proxy_read_timeout    => '5s',
      proxy_send_timeout    => '5s',
    }
  }
}

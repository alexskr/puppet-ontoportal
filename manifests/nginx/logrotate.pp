class ontoportal::nginx::logrotate (
  Integer $logrotate_days = 356,
){

  logrotate::rule { 'nginx':
    path          => ["/var/log/nginx/*.log"],
    rotate        => $logrotate_days,
    rotate_every  => 'day',
    compress      => true,             # Enable compression
    delaycompress => true,             # Delay compression for the most recent rotated log
    missingok     => true,             # Ignore missing logs
    ifempty       => false,             # Do not rotate empty logs
    create        => true,             # Create new log file after rotation
    dateext       => true,
    create_mode   => '0640',            # Permissions for new log file
    create_owner  => 'www-data',           # Owner of new log file
    create_group  => 'adm',            # Group of new log file
    sharedscripts => true,             # Ensure scripts run once for all logs
    postrotate    => '[ -f /var/run/nginx.pid ] && kill -USR1 `cat /run/nginx.pid`',
  }
}

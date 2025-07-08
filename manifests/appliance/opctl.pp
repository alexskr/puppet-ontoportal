# @summary Class for managing the OntoPortal control script (opctl)
#
# This class creates the opctl script and symlink for managing OntoPortal services.
# The opctl script provides a unified interface for starting, stopping, and managing
# various OntoPortal components.
#
# @param triple_store The triple store backend being used (4store, agraph, or external)
# @param include_api Whether the API component is included
# @param include_ui Whether the UI component is included
# @param app_root_dir The root directory for the application code
# @param log_dir The root directory for the application logs
# @param data_dir The root directory for data volumes
# @param admin_user The OntoPortal deployer/admin/ops user
# @param backend_user The service account for running API and ncbo_cron services
# @param ui_user The service account for running UI/puma/rails services
# @param shared_group The Unix group for application data
#
class ontoportal::appliance::opctl (
  Enum['4store', 'agraph', 'external'] $triple_store = 'agraph',
  Boolean $include_api = true,
  Boolean $include_ui = true,
  Boolean $include_cron = true,
  Stdlib::Absolutepath $app_root_dir = '/opt/ontoportal',
  Stdlib::Absolutepath $log_dir = '/var/log/ontoportal',
  Stdlib::Absolutepath $data_dir = '/srv/ontoportal',
  String $admin_user = 'op-admin',
  String $backend_user = 'op-backend',
  String $ui_user = 'op-ui',
  String $shared_group = 'opdata',
) {
  # Create the opctl script
  file { '/usr/local/ontoportal/bin/opctl':
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => epp('ontoportal/usr/local/bin/opctl.epp', {
        'triple_store' => $triple_store,
        'include_api'  => $include_api,
        'include_cron' => $include_cron,
        'include_ui'   => $include_ui,
        'app_root_dir' => $app_root_dir,
        'log_dir'      => $log_dir,
        'data_dir'     => $data_dir,
        'admin_user'   => $admin_user,
        'backend_user' => $backend_user,
        'ui_user'      => $ui_user,
        'shared_group' => $shared_group,
    }),
  }

  # Create symlink to make opctl available in PATH
  file { '/usr/local/bin/opctl':
    ensure => symlink,
    target => '/usr/local/ontoportal/bin/opctl',
  }
}

require 'spec_helper'

describe 'ontoportal::ncbo_cron' do
  on_supported_os({
    supported_os: [
      {
        'operatingsystem' => 'Ubuntu',
        'operatingsystemrelease' => ['22.04']
      },
    ]
  }).each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      let(:params) do
        {
          environment: 'appliance',
          service_account: 'op-backend',
          admin_user: 'op-admin',
          group: 'opdata',
          app_dir: '/opt/ontoportal/ncbo_cron',
          log_dir: '/var/log/ontoportal/ncbo_cron',
          service: 'running',
          data_dir: '/srv/ontoportal',
          ruby_version: '3.1.6',
          logrotate_days: 356,
          manage_java: true,
          manage_ruby: true,
          java_version: 'openjdk-11-jre-headless',
        }
      end

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('ontoportal::params') }

      it 'ensures required Debian packages are installed' do
        [
          'file',
          'libwww-perl',
          'libxml2-dev',
          'raptor2-utils',
        ].each do |pkg|
          expect(subject).to contain_package(pkg).with_ensure('installed')
        end
      end

      it { is_expected.to contain_ontoportal__rbenv('3.1.6').with(global: true) }

      it 'creates app directory with proper ownership and dependencies' do
        is_expected.to contain_file('/opt/ontoportal/ncbo_cron')
          .with(
            ensure: 'directory',
            owner: 'op-admin',
            group: 'opdata',
            mode: '0750',
          )
          .that_requires('Service[ncbo_cron]')
      end

      it 'creates log directory and symlink' do
        is_expected.to contain_file('/var/log/ontoportal/ncbo_cron')
          .with(
            ensure: 'directory',
            owner: 'op-backend',
            group: 'opdata',
            mode: '0750',
          )

        is_expected.to contain_file('/opt/ontoportal/ncbo_cron/log')
          .with(
            ensure: 'link',
            target: '/var/log/ontoportal/ncbo_cron',
          )
      end

      it 'creates the repository directory with sticky group bit' do
        is_expected.to contain_file('/srv/ontoportal/repository')
          .with(
            ensure: 'directory',
            owner: 'op-backend',
            group: 'opdata',
            mode: '2770',
          )
      end

      it 'creates the tmpclean cron file with correct content' do
        is_expected.to contain_file('/etc/cron.d/ncbo_cron_tmpclean')
          .with(
            ensure: 'present',
            owner: 'root',
            group: 'root',
            mode: '0644',
          )
          .with_content(%r{^00 05 \* \* \* root find /tmp/systemd-private-.*-ncbo_cron\.service-.*/tmp/.*})
      end

      it 'includes the java class with correct version' do
        is_expected.to contain_class('java')
          .with(package: 'openjdk-11-jre-headless')
      end

      it 'creates a systemd tmpfile entry' do
        is_expected.to contain_systemd__tmpfile('ncbo_cron.conf')
          .with(
            ensure: 'present',
            content: 'd /run/ncbo_cron 0755 op-backend opdata',
          )
      end

      it { is_expected.to contain_systemd__unit_file('ncbo_cron.service') }

      it 'enables the ncbo_cron service' do
        is_expected.to contain_service('ncbo_cron')
          .with(
            enable: true,
            hasstatus: true,
            hasrestart: true,
          )
      end

      it 'configures logrotate for ncbo_cron logs' do
        is_expected.to contain_logrotate__rule('ncbo_cron')
          .with(
            path: '/var/log/ontoportal/ncbo_cron/*.log',
            rotate: 356,
            minsize: '10M',
            rotate_every: 'day',
            copytruncate: true,
            dateext: true,
            compress: true,
            missingok: true,
            su: true,
            su_user: 'op-backend',
            su_group: 'opdata',
          )
      end
    end
  end
end


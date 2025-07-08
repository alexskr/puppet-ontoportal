require 'spec_helper'

describe 'ontoportal::appliance::opctl' do
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

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('ontoportal::appliance::opctl') }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with(
            'ensure'  => 'file',
            'mode'    => '0755',
            'owner'   => 'root',
            'group'   => 'root',
          )
        }

        it {
          is_expected.to contain_file('/usr/local/bin/opctl').with(
            'ensure' => 'symlink',
            'target' => '/usr/local/ontoportal/bin/opctl',
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{agraph},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{unicorn\.service},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{ui\.service},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{APP_ROOT_DIR="/opt/ontoportal"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{LOG_DIR="/var/log/ontoportal"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{DATA_DIR="/srv/ontoportal"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{ADMIN_USER="op-admin"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{BACKEND_USER="op-backend"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{UI_USER="op-ui"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{SHARED_GROUP="opdata"},
          )
        }
      end

      context 'with custom parameters' do
        let(:params) do
          {
            'triple_store' => '4store',
            'include_api'  => false,
            'include_ui'   => true,
            'app_root_dir' => '/custom/app/root',
            'log_dir'      => '/custom/log/dir',
            'data_dir'     => '/custom/data/dir',
            'admin_user'   => 'custom-admin',
            'backend_user' => 'custom-backend',
            'ui_user'      => 'custom-ui',
            'shared_group' => 'custom-group',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{4store},
          )
        }

        it {
          is_expected.not_to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{unicorn\.service},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{ui\.service},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{APP_ROOT_DIR="/custom/app/root"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{LOG_DIR="/custom/log/dir"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{DATA_DIR="/custom/data/dir"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{ADMIN_USER="custom-admin"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{BACKEND_USER="custom-backend"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{UI_USER="custom-ui"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{SHARED_GROUP="custom-group"},
          )
        }
      end

      context 'with external triple store' do
        let(:params) do
          {
            'triple_store' => 'external',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{external},
          )
        }
      end

      context 'with both API and UI disabled' do
        let(:params) do
          {
            'include_api' => false,
            'include_ui'  => false,
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.not_to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{unicorn\.service},
          )
        }

        it {
          is_expected.not_to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{ui\.service},
          )
        }
      end

      context 'with custom paths' do
        let(:params) do
          {
            'app_root_dir' => '/opt/custom/ontoportal',
            'log_dir'      => '/var/log/custom/ontoportal',
            'data_dir'     => '/srv/custom/ontoportal',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{APP_ROOT_DIR="/opt/custom/ontoportal"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{LOG_DIR="/var/log/custom/ontoportal"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{DATA_DIR="/srv/custom/ontoportal"},
          )
        }
      end

      context 'with custom users and groups' do
        let(:params) do
          {
            'admin_user'   => 'myadmin',
            'backend_user' => 'mybackend',
            'ui_user'      => 'myui',
            'shared_group' => 'mydata',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{ADMIN_USER="myadmin"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{BACKEND_USER="mybackend"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{UI_USER="myui"},
          )
        }

        it {
          is_expected.to contain_file('/usr/local/ontoportal/bin/opctl').with_content(
            %r{SHARED_GROUP="mydata"},
          )
        }
      end
    end
  end
end

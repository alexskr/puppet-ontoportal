require 'spec_helper'

describe 'ontoportal::nginx::cloudflare_proxy' do
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
        it { is_expected.to contain_class('ontoportal::nginx::cloudflare_proxy') }

        it {
          is_expected.to contain_package('nginx-extras').with_ensure('installed')
        }

        it {
          is_expected.to contain_file('/etc/nginx/conf.d/cloudflare_real_ip.conf').with(
            'ensure'  => 'present',
            'owner'   => 'root',
            'group'   => 'root',
            'mode'    => '0644',
            'replace' => false,
          )
        }

        it {
          is_expected.not_to contain_file('/etc/nginx/conf.d/cloudflare_proxy_ip_restrict.conf')
        }

        it {
          is_expected.to contain_file('/usr/local/bin/nginx-cloudflare_proxy_config.sh').with(
            'ensure' => 'present',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0755',
          )
        }

        it {
          is_expected.to contain_cron__job('update_cloudflare_proxy_config').with(
            'ensure'  => 'present',
            'command' => '/usr/local/bin/nginx-cloudflare_proxy_config.sh false',
            'minute'  => '0',
            'hour'    => '*/1',
            'user'    => 'root',
          )
        }
      end

      context 'with block_non_cloudflare => true' do
        let(:params) do
          {
            'block_non_cloudflare' => true
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/nginx/conf.d/cloudflare_proxy_ip_restrict.conf').with(
            'ensure'  => 'present',
            'owner'   => 'root',
            'group'   => 'root',
            'mode'    => '0644',
            'replace' => false,
          )
        }

        it {
          is_expected.to contain_cron__job('update_cloudflare_proxy_config').with(
            'command' => '/usr/local/bin/nginx-cloudflare_proxy_config.sh true',
          )
        }
      end

      context 'with ensure => absent' do
        let(:params) do
          {
            'ensure' => 'absent'
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/nginx/conf.d/cloudflare_real_ip.conf').with_ensure('absent')
        }

        it {
          is_expected.to contain_file('/usr/local/bin/nginx-cloudflare_proxy_config.sh').with_ensure('absent')
        }

        it {
          is_expected.to contain_cron__job('update_cloudflare_proxy_config').with_ensure('absent')
        }
      end
    end
  end
end

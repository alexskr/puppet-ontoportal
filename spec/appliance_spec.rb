require 'spec_helper'

describe 'ontoportal::appliance' do
  let(:facts) { {
    os: {
      family: 'Debian',
      name: 'Ubuntu',
      release: { full: '22.04' }
    }
  } }

  it { is_expected.to compile.with_all_deps }

end


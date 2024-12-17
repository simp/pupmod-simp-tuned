require 'spec_helper'

describe 'tuned' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context 'with default parameters' do
          let(:expected_tuned) { File.read('spec/expected/default_tuned.conf') }
          let(:expected_ktune) { File.read('spec/expected/default_sysconfig_ktune') }

          it { is_expected.to compile.with_all_deps }

          it { is_expected.to contain_file('/etc/tuned.conf').with_content(expected_tuned) }
          it { is_expected.to contain_file('/etc/tuned.conf').that_notifies('Service[tuned]') }

          it { is_expected.to contain_file('/etc/sysconfig/ktune').with_content(expected_ktune) }

          it { is_expected.to contain_file('/etc/sysctl.ktune') }

          it { is_expected.to contain_package('tuned') }
          it {
            is_expected.to contain_service('tuned').with({
                                                           require: ['Package[tuned]', 'File[/etc/sysconfig/ktune]']
                                                         })
          }
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0)
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  name                   :string(255)
#  admin                  :boolean          default(FALSE), not null
#  projects_limit         :integer          default(10)
#  skype                  :string(255)      default(""), not null
#  linkedin               :string(255)      default(""), not null
#  twitter                :string(255)      default(""), not null
#  authentication_token   :string(255)
#  dark_scheme            :boolean          default(FALSE), not null
#  theme_id               :integer          default(1), not null
#  bio                    :string(255)
#  blocked                :boolean          default(FALSE), not null
#  failed_attempts        :integer          default(0)
#  locked_at              :datetime
#  extern_uid             :string(255)
#  provider               :string(255)
#  username               :string(255)
#

require 'spec_helper'

describe User do
  describe "Associations" do
    it { should have_one(:namespace) }
    it { should have_many(:users_projects).dependent(:destroy) }
    it { should have_many(:projects) }
    it { should have_many(:groups) }
    it { should have_many(:my_own_projects).class_name('Project') }
    it { should have_many(:keys).dependent(:destroy) }
    it { should have_many(:events).class_name('Event').dependent(:destroy) }
    it { should have_many(:recent_events).class_name('Event') }
    it { should have_many(:issues).dependent(:destroy) }
    it { should have_many(:notes).dependent(:destroy) }
    it { should have_many(:assigned_issues).dependent(:destroy) }
    it { should have_many(:merge_requests).dependent(:destroy) }
    it { should have_many(:assigned_merge_requests).dependent(:destroy) }
  end

  describe "Mass assignment" do
    it { should_not allow_mass_assignment_of(:projects_limit) }
    it { should allow_mass_assignment_of(:projects_limit).as(:admin) }
  end

  describe 'validations' do
    it { should validate_presence_of(:username) }
    it { should validate_presence_of(:projects_limit) }
    it { should validate_numericality_of(:projects_limit) }
    it { should allow_value(0).for(:projects_limit) }
    it { should_not allow_value(-1).for(:projects_limit) }

    it { should ensure_length_of(:bio).is_within(0..255) }
  end

  describe "Respond to" do
    it { should respond_to(:is_admin?) }
    it { should respond_to(:identifier) }
    it { should respond_to(:name) }
    it { should respond_to(:private_token) }
  end

  describe '#identifier' do
    it "should return valid identifier" do
      user = build(:user, email: "test@mail.com")
      user.identifier.should == "test_mail_com"
    end

    it "should return identifier without + sign" do
      user = build(:user, email: "test+foo@mail.com")
      user.identifier.should == "test_foo_mail_com"
    end

    it "should conform to Gitolite's required identifier pattern" do
      user = build(:user, email: "_test@example.com")
      user.identifier.should == 'test_example_com'
    end
  end

  describe '#generate_password' do
    it "should execute callback when force_random_password specified" do
      user = build(:user, force_random_password: true)
      user.should_receive(:generate_password)
      user.save
    end

    it "should not generate password by default" do
      user = create(:user, password: 'abcdefg')
      user.password.should == 'abcdefg'
    end

    it "should generate password when forcing random password" do
      Devise.stub(:friendly_token).and_return('123456789')
      user = create(:user, password: 'abcdefg', force_random_password: true)
      user.password.should == '12345678'
    end
  end

  describe 'authentication token' do
    it "should have authentication token" do
      user = create(:user)
      user.authentication_token.should_not be_blank
    end
  end
end

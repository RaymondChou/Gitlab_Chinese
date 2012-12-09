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

class User < ActiveRecord::Base
  include Account

  devise :database_authenticatable, :token_authenticatable, :lockable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  attr_accessible :email, :password, :password_confirmation, :remember_me, :bio, :name, :username,
                  :skype, :linkedin, :twitter, :dark_scheme, :theme_id, :force_random_password,
                  :extern_uid, :provider, as: [:default, :admin]
  attr_accessible :projects_limit, as: :admin

  attr_accessor :force_random_password

  # Namespace for personal projects
  has_one :namespace, class_name: "Namespace", foreign_key: :owner_id, conditions: 'type IS NULL', dependent: :destroy
  has_many :groups, class_name: "Group", foreign_key: :owner_id

  has_many :keys, dependent: :destroy
  has_many :projects, through: :users_projects
  has_many :users_projects, dependent: :destroy
  has_many :issues, foreign_key: :author_id, dependent: :destroy
  has_many :notes, foreign_key: :author_id, dependent: :destroy
  has_many :merge_requests, foreign_key: :author_id, dependent: :destroy
  has_many :my_own_projects, class_name: "Project", foreign_key: :owner_id
  has_many :events, class_name: "Event", foreign_key: :author_id, dependent: :destroy
  has_many :recent_events, class_name: "Event", foreign_key: :author_id, order: "id DESC"
  has_many :assigned_issues, class_name: "Issue", foreign_key: :assignee_id, dependent: :destroy
  has_many :assigned_merge_requests, class_name: "MergeRequest", foreign_key: :assignee_id, dependent: :destroy

  validates :bio, length: { within: 0..255 }
  validates :extern_uid, allow_blank: true, uniqueness: {scope: :provider}
  validates :projects_limit, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :username, presence: true, uniqueness: true,
            format: { with: Gitlab::Regex.username_regex,
                      message: "only letters, digits & '_' '-' '.' allowed. Letter should be first" }


  before_validation :generate_password, on: :create
  before_save :ensure_authentication_token
  alias_attribute :private_token, :authentication_token

  delegate :path, to: :namespace, allow_nil: true, prefix: true

  # Scopes
  scope :not_in_project, ->(project) { where("id not in (:ids)", ids: project.users.map(&:id) ) }
  scope :admins, where(admin:  true)
  scope :blocked, where(blocked:  true)
  scope :active, where(blocked:  false)

  class << self
    def filter filter_name
      case filter_name
      when "admins"; self.admins
      when "blocked"; self.blocked
      when "wop"; self.without_projects
      else
        self.active
      end
    end

    def without_projects
      where('id NOT IN (SELECT DISTINCT(user_id) FROM users_projects)')
    end

    def create_from_omniauth(auth, ldap = false)
      gitlab_auth.create_from_omniauth(auth, ldap)
    end

    def find_or_new_for_omniauth(auth)
      gitlab_auth.find_or_new_for_omniauth(auth)
    end

    def find_for_ldap_auth(auth, signed_in_resource = nil)
      gitlab_auth.find_for_ldap_auth(auth, signed_in_resource)
    end

    def gitlab_auth
      Gitlab::Auth.new
    end

    def search query
      where("name LIKE :query or email LIKE :query", query: "%#{query}%")
    end
  end

  def generate_password
    if self.force_random_password
      self.password = self.password_confirmation = Devise.friendly_token.first(8)
    end
  end

  def authorized_groups
    @authorized_groups ||= begin
                           groups = Group.where(id: self.projects.pluck(:namespace_id)).all
                           groups = groups + self.groups
                           groups.uniq
                         end
  end

  def authorized_projects
    Project.authorized_for(self)
  end
end

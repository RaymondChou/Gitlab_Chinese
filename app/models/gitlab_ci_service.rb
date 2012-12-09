# == Schema Information
#
# Table name: services
#
#  id          :integer          not null, primary key
#  type        :string(255)
#  title       :string(255)
#  token       :string(255)
#  project_id  :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  active      :boolean          default(FALSE), not null
#  project_url :string(255)
#

class GitlabCiService < Service
  attr_accessible :project_url

  validates :project_url, presence: true, if: :activated?
  validates :token, presence: true, if: :activated?

  delegate :execute, to: :service_hook, prefix: nil

  after_save :compose_service_hook, if: :activated?

  def activated?
    active
  end

  def compose_service_hook
    hook = service_hook || build_service_hook
    hook.url = [project_url, "/build", "?token=#{token}"].join("")
    hook.save
  end

  def commit_badge_path sha
    project_url + "/status?sha=#{sha}"
  end
end

# == Schema Information
#
# Table name: protected_branches
#
#  id         :integer          not null, primary key
#  project_id :integer          not null
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ProtectedBranch < ActiveRecord::Base
  include GitHost

  attr_accessible :name

  belongs_to :project
  validates :name, presence: true
  validates :project, presence: true

  after_save :update_repository
  after_destroy :update_repository

  def update_repository
    git_host.update_repository(project)
  end

  def commit
    project.commit(self.name)
  end
end

# == Schema Information
#
# Table name: merge_requests
#
#  id            :integer          not null, primary key
#  target_branch :string(255)      not null
#  source_branch :string(255)      not null
#  project_id    :integer          not null
#  author_id     :integer
#  assignee_id   :integer
#  title         :string(255)
#  closed        :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  st_commits    :text(2147483647)
#  st_diffs      :text(2147483647)
#  merged        :boolean          default(FALSE), not null
#  state         :integer          default(1), not null
#  milestone_id  :integer
#

require Rails.root.join("app/models/commit")
require Rails.root.join("app/roles/static_model")

class MergeRequest < ActiveRecord::Base
  include IssueCommonality
  include Votes

  attr_accessible :title, :assignee_id, :closed, :target_branch, :source_branch, :milestone_id,
                  :author_id_of_changes

  attr_accessor :should_remove_source_branch

  BROKEN_DIFF = "--broken-diff"

  UNCHECKED = 1
  CAN_BE_MERGED = 2
  CANNOT_BE_MERGED = 3

  serialize :st_commits
  serialize :st_diffs

  validates :source_branch, presence: true
  validates :target_branch, presence: true
  validate :validate_branches

  def self.find_all_by_branch(branch_name)
    where("source_branch LIKE :branch OR target_branch LIKE :branch", branch: branch_name)
  end

  def self.find_all_by_milestone(milestone)
    where("milestone_id = :milestone_id", milestone_id: milestone)
  end

  def human_state
    states = {
      CAN_BE_MERGED =>  "can_be_merged",
      CANNOT_BE_MERGED => "cannot_be_merged",
      UNCHECKED => "unchecked"
    }
    states[self.state]
  end

  def validate_branches
    if target_branch == source_branch
      errors.add :base, "You can not use same branch for source and target branches"
    end
  end

  def reload_code
    self.reloaded_commits
    self.reloaded_diffs
  end

  def unchecked?
    state == UNCHECKED
  end

  def mark_as_unchecked
    self.state = UNCHECKED
    self.save
  end

  def can_be_merged?
    state == CAN_BE_MERGED
  end

  def check_if_can_be_merged
    self.state = if Gitlab::Satellite::MergeAction.new(self.author, self).can_be_merged?
                   CAN_BE_MERGED
                 else
                   CANNOT_BE_MERGED
                 end
    self.save
  end

  def diffs
    st_diffs || []
  end

  def reloaded_diffs
    if open? && unmerged_diffs.any?
      self.st_diffs = unmerged_diffs
      self.save
    end

  rescue Grit::Git::GitTimeout
    self.st_diffs = [BROKEN_DIFF]
    self.save
  end

  def broken_diffs?
    diffs == [BROKEN_DIFF]
  end

  def valid_diffs?
    !broken_diffs?
  end

  def unmerged_diffs
    # Only show what is new in the source branch compared to the target branch, not the other way around.
    # The linex below with merge_base is equivalent to diff with three dots (git diff branch1...branch2)
    # From the git documentation: "git diff A...B" is equivalent to "git diff $(git-merge-base A B) B"
    common_commit = project.repo.git.native(:merge_base, {}, [target_branch, source_branch]).strip
    diffs = project.repo.diff(common_commit, source_branch)
  end

  def last_commit
    commits.first
  end

  def merged?
    merged && merge_event
  end

  def merge_event
    self.project.events.where(target_id: self.id, target_type: "MergeRequest", action: Event::Merged).last
  end

  def closed_event
    self.project.events.where(target_id: self.id, target_type: "MergeRequest", action: Event::Closed).last
  end

  def commits
    st_commits || []
  end

  def probably_merged?
    unmerged_commits.empty? &&
      commits.any? && open?
  end

  def open?
    !closed
  end

  def mark_as_merged!
    self.merged = true
    self.closed = true
    save
  end

  def mark_as_unmergable
    self.state = CANNOT_BE_MERGED
    self.save
  end

  def reloaded_commits
    if open? && unmerged_commits.any?
      self.st_commits = unmerged_commits
      save
    end
    commits
  end

  def unmerged_commits
    self.project.repo.
      commits_between(self.target_branch, self.source_branch).
      map {|c| Commit.new(c)}.
      sort_by(&:created_at).
      reverse
  end

  def merge!(user_id)
    self.mark_as_merged!
    Event.create(
      project: self.project,
      action: Event::Merged,
      target_id: self.id,
      target_type: "MergeRequest",
      author_id: user_id
    )
  end

  def automerge!(current_user)
    if Gitlab::Satellite::MergeAction.new(current_user, self).merge! && self.unmerged_commits.empty?
      self.merge!(current_user.id)
      true
    end
  rescue
    self.mark_as_unmergable
    false
  end

  def mr_and_commit_notes
    commit_ids = commits.map(&:id)
    Note.where("(noteable_type = 'MergeRequest' AND noteable_id = :mr_id) OR (noteable_type = 'Commit' AND noteable_id IN (:commit_ids))", mr_id: id, commit_ids: commit_ids)
  end

  # Returns the raw diff for this merge request
  #
  # see "git diff"
  def to_diff
    project.repo.git.native(:diff, {timeout: 30, raise: true}, "#{target_branch}...#{source_branch}")
  end

  # Returns the commit as a series of email patches.
  #
  # see "git format-patch"
  def to_patch
    project.repo.git.format_patch({timeout: 30, raise: true, stdout: true}, "#{target_branch}..#{source_branch}")
  end
end

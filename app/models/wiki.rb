# == Schema Information
#
# Table name: wikis
#
#  id         :integer          not null, primary key
#  title      :string(255)
#  content    :text
#  project_id :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  slug       :string(255)
#  user_id    :integer
#

class Wiki < ActiveRecord::Base
  attr_accessible :title, :content, :slug

  belongs_to :project
  belongs_to :user
  has_many :notes, as: :noteable, dependent: :destroy

  validates :content, presence: true
  validates :user, presence: true
  validates :title, presence: true, length: 1..250

  before_update :set_slug

  def to_param
    slug
  end

  class << self
    def search(query)
      where("title like :query OR content like :query", query: "%#{query}%")
    end
  end

  protected

  def self.regenerate_from wiki
    regenerated_field = [:slug, :content, :title]

    new_wiki = Wiki.new
    regenerated_field.each do |field|
      new_wiki.send("#{field}=", wiki.send(field))
    end
    new_wiki
  end

  def set_slug
    self.slug = self.title.parameterize
  end

end

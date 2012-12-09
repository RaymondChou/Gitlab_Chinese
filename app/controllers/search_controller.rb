class SearchController < ApplicationController
  def show
    result = SearchContext.new(current_user.project_ids, params).execute

    @projects       = result[:projects]
    @merge_requests = result[:merge_requests]
    @issues         = result[:issues]
    @wiki_pages     = result[:wiki_pages]
  end
end

# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @query = params[:q].to_s
    return if @query.blank?

    @response = RecordingStudio::WebSearch.search(@query)
  rescue RecordingStudio::WebSearch::Error => e
    @error = e
  end
end

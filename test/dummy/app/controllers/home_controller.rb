# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @query = params[:q].to_s
    @provider = provider_param
    @provider_options = provider_options
    return if @query.blank?

    @response = RecordingStudio::WebSearch.search(@query, provider: @provider)
  rescue RecordingStudio::WebSearch::Error => e
    @error = e
  end

  private

  def provider_param
    params[:provider].presence || RecordingStudio::WebSearch.configuration.provider.to_s
  end

  def provider_options
    RecordingStudio::WebSearch.provider_names.map do |name|
      [RecordingStudio::WebSearch::ProviderCatalog.label_for(name), name.to_s]
    end
  end
end

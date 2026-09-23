# frozen_string_literal: true

RecordingStudio::WebSearch::Engine.routes.draw do
  root "home#index"
  resources :runs, only: [:show]
end

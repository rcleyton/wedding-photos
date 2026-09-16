require "rails_helper"

RSpec.describe "Rails health check", type: :request do
  it "responds without authentication" do
    get rails_health_check_path

    expect(response).to have_http_status(:ok)
  end
end

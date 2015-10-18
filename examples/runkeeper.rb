class Activity
  include HTTParty

  hostport = "api.runkeeper.com"
  base_uri "http://#{hostport}"
  format :json

  def self.grab_user
    headers 'Authorization' => 'Bearer ENV["RUN_KEEPER_TOKEN"]', 'Accept' => "application/vnd.com.runkeeper.User+json"
    get("/user")
  end

  def self.grab_activities
    headers 'Authorization' => 'Bearer ENV["RUN_KEEPER_TOKEN"]', 'Accept' => "application/vnd.com.runkeeper.FitnessActivityFeed+json"
    get("/fitnessActivities")["items"]
  end
end


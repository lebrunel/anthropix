import Config

# To run integeration tests, create a file named `config/local.exs`
# with the following content:
#
# ```ex
# import Config
# config :anthropix, :api_key, "your_api_key"
# ```
#
# Then run:
#
# ```sh
# mix test --only integration
# ```
if config_env() in [:dev, :test] and File.exists?("config/local.exs") do
  import_config "local.exs"
end

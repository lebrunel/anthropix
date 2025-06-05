import Config

# To run integeration tests, create a file named `config/secret.exs`
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
if config_env() in [:dev, :test] and File.exists?("config/secret.exs") do
  import_config "secret.exs"
end

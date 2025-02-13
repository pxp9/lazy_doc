import Config

if Mix.env() == :dev do
  Dotenv.load!()
end

config :lazy_doc, :token, System.get_env("API_TOKEN")

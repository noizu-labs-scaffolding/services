import Config

config :junit_formatter,
       report_file: "results.xml"

config :noizu_labs_services,
       configuration: Noizu.Service.Support.NodeManager.ConfigurationProvider

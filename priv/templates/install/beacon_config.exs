config :beacon, otp_app: :<%= ctx_app %>

config :beacon, Beacon,
  sites: [
    <%= beacon_site %>: [
      data_source: <%= inspect beacon_data_source.module_name %>
    ]
  ]

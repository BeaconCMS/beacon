config :beacon, otp_app: :<%= ctx_app %>

config :<%= ctx_app %>, Beacon,
  sites: [
    <%= beacon_site %>: [
      data_source: <%= inspect beacon_data_source.module_name %>
    ]
  ]

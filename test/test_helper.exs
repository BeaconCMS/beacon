Application.put_env(:beacon, Beacon.BeaconTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
  live_view: [signing_salt: "ykjYicLHN3EuW0FO"],
  render_errors: [view: Beacon.BeaconTest.ErrorView],
  pubsub_server: Beacon.BeaconTest.PubSub,
  check_origin: false,
  debug_errors: true
)

Supervisor.start_link(
  [
    {Phoenix.PubSub, name: Beacon.BeaconTest.PubSub},
    {Beacon,
     sites: [
       [
         site: :my_site,
         endpoint: Beacon.BeaconTest.Endpoint,
         tailwind_config: Path.join([File.cwd!(), "test", "support", "tailwind.config.templates.js.eex"]),
         data_source: Beacon.BeaconTest.BeaconDataSource,
         live_socket_path: "/custom_live",
         extra_page_fields: [Beacon.BeaconTest.PageFields.TagsField]
       ],
       [
         site: :s3_site,
         endpoint: Beacon.BeaconTest.Endpoint,
         assets: [
           {"image/*", [backends: [Beacon.MediaLibrary.Backend.S3, Beacon.MediaLibrary.Backend.Repo], validations: []]}
         ],
         lifecycle: [upload_asset: []]
       ],
       [
         site: :data_source_test,
         endpoint: Beacon.BeaconTest.Endpoint,
         data_source: Beacon.BeaconTest.TestDataSource
       ],
       [
         site: :default_meta_tags_test,
         endpoint: Beacon.BeaconTest.Endpoint,
         data_source: Beacon.BeaconTest.BeaconDataSource,
         default_meta_tags: [
           %{"name" => "foo_meta_tag"},
           %{"name" => "bar_meta_tag"},
           %{"name" => "baz_meta_tag"}
         ]
       ],
       [
         site: :lifecycle_test,
         endpoint: Beacon.BeaconTest.Endpoint,
         lifecycle: [
           load_template: [
             {:markdown,
              [
                assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
                downcase: fn template, _metadata -> {:cont, String.downcase(template)} end
              ]}
           ],
           render_template: [
             {:markdown,
              [
                div_to_p: fn template, _metadata -> {:cont, String.replace(template, "div", "p")} end,
                assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
                compile: fn template, _metadata ->
                  ast = Beacon.Template.HEEx.compile_heex_template!("nofile", template)
                  {:cont, ast}
                end,
                eval: fn template, _metadata ->
                  {rendered, _bindings} = Code.eval_quoted(template, [assigns: %{}], file: "nofile")
                  {:halt, rendered}
                end
              ]}
           ],
           after_create_page: [
             maybe_create_page: fn page ->
               send(self(), :lifecycle_after_create_page)
               {:cont, page}
             end
           ],
           after_update_page: [
             maybe_update_page: fn page ->
               send(self(), :lifecycle_after_update_page)
               {:cont, page}
             end
           ],
           after_publish_page: [
             maybe_publish_page: fn page ->
               send(self(), :lifecycle_after_publish_page)
               {:cont, page}
             end
           ]
         ]
       ],
       [
         site: :lifecycle_test_fail,
         endpoint: Beacon.BeaconTest.Endpoint,
         lifecycle: [
           render_template: [
             {:markdown, [assigns: fn template, _metadata -> {:cont, template} end]}
           ]
         ]
       ]
     ],
     authorization_source: Beacon.BeaconTest.BeaconAuthorizationSource},
    Beacon.BeaconTest.Endpoint
  ],
  strategy: :one_for_one
)

ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(Beacon.Repo, :manual)

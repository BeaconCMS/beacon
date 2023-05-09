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
         tailwind_config: Path.join([File.cwd!(), "test", "support", "tailwind.config.js.eex"]),
         data_source: Beacon.BeaconTest.BeaconDataSource,
         live_socket_path: "/custom_live",
         extra_page_fields: [Beacon.BeaconTest.PageFields.TagsField]
       ],
       [
         site: :data_source_test,
         data_source: Beacon.BeaconTest.TestDataSource
       ],
       [
         site: :lifecycle_test,
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
           create_page: [
             maybe_create_page: fn _page ->
               {:cont, %Beacon.Pages.Page{template: "<h1>Created</h1>"}}
             end
           ],
           update_page: [
             maybe_update_page: fn _page ->
               {:cont, %Beacon.Pages.Page{template: "<h1>Updated</h1>"}}
             end
           ],
           publish_page: [
             maybe_publish_page: fn _page ->
               {:cont, %Beacon.Pages.Page{status: :published}}
             end
           ]
         ]
       ],
       [
         site: :lifecycle_test_fail,
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

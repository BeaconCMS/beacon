defmodule Beacon.Support.BypassHelpers do
  # port 5555 is selected because we are matching the aws test creds in test.exs
  def start_bypass(_) do
    bypass = Bypass.open(port: 5555)
    [bypass: bypass]
  end

  # beacon-media-library matches the bucket in the aws test creds in test.exs
  def setup_multipart_upload_backend(bypass, test_pid, key, opts \\ []) do
    bucket = Keyword.get(opts, :bucket, "beacon-media-library")
    upload_id = Keyword.get(opts, :upload_id, "a-very-secret-upload")
    request_path = "/#{bucket}/#{key}"

    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn do
        %{method: "POST", request_path: ^request_path, query_params: %{"uploadId" => ^upload_id}} ->
          send(test_pid, :completed_upload)

          conn
          |> Plug.Conn.send_resp(200, "")

        %{method: "POST", request_path: ^request_path} ->
          body = """
          <InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Bucket>beacon-media-library</Bucket>
            <Key>#{key}</Key>
            <UploadId>#{upload_id}</UploadId>
          </InitiateMultipartUploadResult>
          """

          send(test_pid, :initiated_upload)

          conn
          |> Plug.Conn.send_resp(200, body)

        %{method: "PUT", request_path: ^request_path} ->
          send(test_pid, :chunk_uploaded)

          conn
          |> Plug.Conn.put_resp_header("ETag", "abc123")
          |> Plug.Conn.send_resp(200, "")

        conn ->
          raise """
          Mock Configuration error.

          Expected to match
          Method: POST or PUT
          Request path: #{request_path}
          Query params: %{"uploadId" => #{upload_id}}

          Given
          Method #{conn.method}
          Request path: #{conn.request_path}
          Query params: #{inspect(conn.query_params)}


          conn: #{inspect(conn)}
          """
      end
    end)
  end
end

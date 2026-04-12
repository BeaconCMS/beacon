defmodule Beacon.Actions.SecurityTest do
  use ExUnit.Case, async: true

  alias Beacon.Actions.Security

  @secret "test-signing-secret-key-32bytes!"

  describe "sign/2 and verify/3" do
    test "signs and verifies an action document" do
      doc = %{"version" => 1, "steps" => [%{"action" => "navigate", "to" => "/"}]}
      signature = Security.sign(doc, @secret)

      assert is_binary(signature)
      assert Security.verify(doc, signature, @secret)
    end

    test "verification fails with wrong secret" do
      doc = %{"steps" => [%{"action" => "flash", "kind" => "info", "message" => "hi"}]}
      signature = Security.sign(doc, @secret)

      refute Security.verify(doc, signature, "wrong-secret-key-32bytes!!!!!!!!!")
    end

    test "verification fails with tampered document" do
      doc = %{"steps" => [%{"action" => "navigate", "to" => "/safe"}]}
      signature = Security.sign(doc, @secret)

      tampered = %{"steps" => [%{"action" => "navigate", "to" => "/evil"}]}
      refute Security.verify(tampered, signature, @secret)
    end

    test "verification fails with wrong signature" do
      doc = %{"steps" => []}
      refute Security.verify(doc, "invalid-signature", @secret)
    end

    test "different documents produce different signatures" do
      doc1 = %{"steps" => [%{"action" => "navigate", "to" => "/a"}]}
      doc2 = %{"steps" => [%{"action" => "navigate", "to" => "/b"}]}

      sig1 = Security.sign(doc1, @secret)
      sig2 = Security.sign(doc2, @secret)

      assert sig1 != sig2
    end
  end
end

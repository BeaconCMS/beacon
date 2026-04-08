defmodule Beacon.Web.Warming do
  @moduledoc """
  Default warming template rendered while CSS is compiling on first request.

  Sites can override this by setting `css_warming_template` in their Beacon config
  to a function that returns an HTML string:

      config :beacon, my_site: [
        css_warming_template: fn -> "<div>Loading...</div>" end
      ]

  The template is rendered inside the LiveView (not the root layout), so it
  should be a fragment — not a full HTML document. It will be displayed with
  the root layout's `<head>` (including LiveView JS), but without the site's
  compiled CSS stylesheet.
  """

  @doc """
  Returns the warming template HTML for the given site.
  """
  def render(site) do
    config = Beacon.Config.fetch!(site)

    case config.css_warming_template do
      fun when is_function(fun, 0) -> fun.()
      _ -> default_template()
    end
  end

  defp default_template do
    ~s"""
    <div id="beacon-warming" style="position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:#f9fafb;font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;z-index:9999;flex-direction:column;padding:24px">
      <div style="text-align:center;max-width:420px">
        <div style="margin:0 auto 24px;position:relative;width:48px;height:48px">
          #{lighthouse_svg()}
          #{pulse_rings()}
        </div>
        <h1 style="color:#1e293b;font-size:20px;font-weight:600;margin:0 0 8px;letter-spacing:-0.01em">Preparing assets</h1>
        <p style="color:#64748b;font-size:15px;line-height:1.6;margin:0 0 24px">Your site is warming up. This page will automatically update once everything is ready.</p>
        #{progress_bar()}
      </div>
    </div>
    <style>
      @keyframes beacon-pulse{0%{transform:scale(1);opacity:0.5}100%{transform:scale(2.5);opacity:0}}
      @keyframes beacon-glow{0%,100%{filter:drop-shadow(0 0 3px #f59e0b)}50%{filter:drop-shadow(0 0 8px #fbbf24)}}
      @keyframes beacon-progress{0%{width:5%}50%{width:60%}90%{width:85%}100%{width:95%}}
    </style>
    """
  end

  defp lighthouse_svg do
    ~s"""
    <svg width="48" height="48" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg" style="position:relative;z-index:1;animation:beacon-glow 2s ease-in-out infinite">
      <!-- Base platform -->
      <rect x="14" y="40" width="20" height="4" rx="2" fill="#6366f1"/>
      <!-- Tower body -->
      <path d="M17 40V18h14v22" fill="#818cf8"/>
      <!-- Stripe -->
      <rect x="17" y="28" width="14" height="3" fill="#6366f1" opacity="0.4"/>
      <rect x="17" y="34" width="14" height="3" fill="#6366f1" opacity="0.4"/>
      <!-- Lamp room -->
      <rect x="15" y="13" width="18" height="6" rx="2" fill="#6366f1"/>
      <!-- Roof -->
      <path d="M18 13l6-6 6 6" fill="#4f46e5"/>
      <!-- Lamp -->
      <circle cx="24" cy="16" r="2.5" fill="#fbbf24"/>
      <!-- Light beams -->
      <path d="M15 16L4 12v2l11 4z" fill="#fbbf24" opacity="0.5"/>
      <path d="M33 16l11-4v2l-11 4z" fill="#fbbf24" opacity="0.5"/>
      <path d="M15 16L6 20v-2l9-4z" fill="#fbbf24" opacity="0.3"/>
      <path d="M33 16l9 4v-2l-9-4z" fill="#fbbf24" opacity="0.3"/>
      <!-- Window -->
      <rect x="21.5" y="23" width="5" height="6" rx="2.5" fill="#c7d2fe"/>
    </svg>
    """
  end

  defp pulse_rings do
    ~s"""
    <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;pointer-events:none">
      <div style="position:absolute;width:20px;height:20px;border-radius:50%;border:2px solid #818cf8;animation:beacon-pulse 2s ease-out infinite;top:50%;left:50%;margin:-10px 0 0 -10px"></div>
      <div style="position:absolute;width:20px;height:20px;border-radius:50%;border:2px solid #818cf8;animation:beacon-pulse 2s ease-out infinite 0.6s;top:50%;left:50%;margin:-10px 0 0 -10px"></div>
      <div style="position:absolute;width:20px;height:20px;border-radius:50%;border:2px solid #818cf8;animation:beacon-pulse 2s ease-out infinite 1.2s;top:50%;left:50%;margin:-10px 0 0 -10px"></div>
    </div>
    """
  end

  defp progress_bar do
    ~s"""
    <div style="width:100%;height:4px;background:#e2e8f0;border-radius:2px;overflow:hidden">
      <div style="height:100%;background:linear-gradient(90deg,#6366f1,#818cf8);border-radius:2px;animation:beacon-progress 12s ease-out forwards"></div>
    </div>
    """
  end
end

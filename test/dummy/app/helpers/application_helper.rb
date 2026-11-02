module ApplicationHelper
  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    # The default layout strips these slots, which drops html safety, then
    # PageTitle escapes again. Store the raw characters so that escape happens once.
    content_for(:title, title.to_s.html_safe) if title.present?
    content_for(:subtitle, subtitle.to_s.html_safe) if subtitle.present?
    flat_pack_page_nav(
      round: true,
      style: :default,
      back_href: back_url,
      back_tooltip: back_label
    )

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Admin",
          style: :ghost,
          size: :md,
          href: admin_root_path
        )
      )
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          href: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end

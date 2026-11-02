module ApplicationHelper
  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    # The default layout strips content_for :title, then PageTitle escapes it
    # again. Draw the heading here so the plain string is escaped once.
    if title.present?
      concat render(
        FlatPack::PageTitle::Component.new(title: title.to_s, subtitle: subtitle.presence&.to_s)
      )
    end
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

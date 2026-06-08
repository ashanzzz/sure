require "test_helper"

class UserMenuViewTest < ActionView::TestCase
  test "ledger switch posts active family under current_session scope" do
    user = users(:family_admin)
    Current.session = user.sessions.create!
    additional_family = Family.create!(name: "Business")
    FamilyMembership.create!(user: user, family: additional_family)
    view.singleton_class.define_method(:self_hosted?) { false }

    html = render(partial: "users/user_menu", locals: { user: user })

    assert_includes html, 'name="current_session[active_family_id]"'
    assert_not_includes html, 'name="active_family_id"'
  end

  test "ledger switch shows only membership ledgers with current and role context" do
    user = users(:family_admin)
    Current.session = user.sessions.create!
    additional_family = Family.create!(name: "Business")
    FamilyMembership.create!(user: user, family: additional_family, role: "member")
    Current.session.set_active_family_id(additional_family.id)
    unrelated_family = Family.create!(name: "Other Ledger")
    view.singleton_class.define_method(:self_hosted?) { false }

    html = render(partial: "users/user_menu", locals: { user: user })

    assert_includes html, "Business"
    assert_includes html, I18n.t("users.user_menu.current_ledger")
    assert_includes html, I18n.t("users.roles.member")
    assert_not_includes html, unrelated_family.name
  end
end

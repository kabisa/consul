require "rails_helper"
require "sessions_helper"

describe "Budget Investments" do
  let(:author)  { create(:user, :level_two, username: "Isabel") }
  let(:budget)  { create(:budget, name: "Big Budget") }
  let(:other_budget) { create(:budget, name: "What a Budget!") }
  let(:group) { create(:budget_group, name: "Health", budget: budget) }
  let!(:heading) { create(:budget_heading, name: "More hospitals", price: 666666, group: group) }

  it_behaves_like "milestoneable", :budget_investment

  context "Concerns" do
    it_behaves_like "notifiable in-app", :budget_investment
    it_behaves_like "relationable", Budget::Investment
    it_behaves_like "remotely_translatable",
                    :budget_investment,
                    "budget_investments_path",
                    { "budget_id": "budget_id" }

    it_behaves_like "remotely_translatable",
                    :budget_investment,
                    "budget_investment_path",
                    { "budget_id": "budget_id", "id": "id" }
    it_behaves_like "flaggable", :budget_investment
  end

  context "Load" do
    let(:investment) { create(:budget_investment, heading: heading) }

    before do
      budget.update!(slug: "budget_slug")
      heading.update!(slug: "heading_slug")
    end

    scenario "finds investment using budget slug" do
      visit budget_investment_path("budget_slug", investment)

      expect(page).to have_content investment.title
    end

    scenario "raises an error if budget slug is not found" do
      expect do
        visit budget_investment_path("wrong_budget", investment)
      end.to raise_error ActiveRecord::RecordNotFound
    end

    scenario "raises an error if budget id is not found" do
      expect do
        visit budget_investment_path(0, investment)
      end.to raise_error ActiveRecord::RecordNotFound
    end

    scenario "finds investment using heading slug" do
      visit budget_investment_path(budget, investment, heading_id: "heading_slug")

      expect(page).to have_content investment.title
    end

    scenario "raises an error if heading slug is not found" do
      expect do
        visit budget_investment_path(budget, investment, heading_id: "wrong_heading")
      end.to raise_error ActiveRecord::RecordNotFound
    end

    scenario "raises an error if heading id is not found" do
      expect do
        visit budget_investment_path(budget, investment, heading_id: 0)
      end.to raise_error ActiveRecord::RecordNotFound
    end
  end

  scenario "Index" do
    investments = [create(:budget_investment, heading: heading),
                   create(:budget_investment, heading: heading),
                   create(:budget_investment, :feasible, heading: heading)]

    unfeasible_investment = create(:budget_investment, :unfeasible, heading: heading)

    visit budget_path(budget)
    click_link "See all investments"

    expect(page).to have_selector("#budget-investments .budget-investment", count: 3)
    investments.each do |investment|
      within("#budget-investments") do
        expect(page).to have_content investment.title
        expect(page).to have_content investment.comments_count
        comments_link = budget_investment_path(budget, id: investment.id, anchor: "comments")
        expect(page).to have_css("a[href=\"#{comments_link}\"]", text: "No comments")
        expect(page).to have_css("a[href='#{budget_investment_path(budget, id: investment.id)}']", text: investment.title)
        expect(page).not_to have_content(unfeasible_investment.title)
      end
    end
  end

  scenario "Index view mode" do
    investments = [create(:budget_investment, heading: heading),
                   create(:budget_investment, heading: heading),
                   create(:budget_investment, heading: heading)]

    visit budget_path(budget)
    click_link "See all investments"

    click_button "View mode"

    click_link "List"

    investments.each do |investment|
      within("#budget-investments") do
        expect(page).to     have_link investment.title
        expect(page).not_to have_content(investment.description)
      end
    end

    click_button "View mode"

    click_link "Cards"

    investments.each do |investment|
      within("#budget-investments") do
        expect(page).to have_link investment.title
        expect(page).to have_content(investment.description)
      end
    end
  end

  scenario "Index should show investment descriptive image only when is defined" do
    investment = create(:budget_investment, heading: heading)
    investment_with_image = create(:budget_investment, :with_image, heading: heading)

    visit budget_investments_path(budget, heading_id: heading.id)

    within("#budget_investment_#{investment.id}") do
      expect(page).not_to have_css("div.with-image")
    end
    within("#budget_investment_#{investment_with_image.id}") do
      expect(page).to have_css("img[alt='#{investment_with_image.image.title}']")
    end
  end

  scenario "Can visit an investment from image link" do
    investment = create(:budget_investment, :with_image, heading: heading)

    visit budget_investments_path(budget, heading_id: heading.id)

    within("#budget_investment_#{investment.id}") do
      find("#image_#{investment.image.id}").click
    end

    expect(page).to have_current_path(budget_investment_path(budget, id: investment.id))
  end

  scenario "Index should show a map if heading has coordinates defined", :js do
    create(:budget_investment, heading: heading)
    visit budget_investments_path(budget, heading_id: heading.id)
    within("#sidebar") do
      expect(page).to have_css(".map_location")
    end

    unlocated_heading = create(:budget_heading, name: "No Map", price: 500, group: group,
                               longitude: nil, latitude: nil)
    create(:budget_investment, heading: unlocated_heading)
    visit budget_investments_path(budget, heading_id: unlocated_heading.id)
    within("#sidebar") do
      expect(page).not_to have_css(".map_location")
    end
  end

  scenario "Index filter by status", :js do
    budget_new  = create(:budget)
    group_new   = create(:budget_group, budget: budget_new)
    heading_new = create(:budget_heading, group: group_new)

    create_list(:budget_investment, 2, :feasible, heading: heading_new)
    create_list(:budget_investment, 2, :unfeasible, heading: heading_new)
    create_list(:budget_investment, 2, :unselected, heading: heading_new)
    create_list(:budget_investment, 2, :selected, heading: heading_new)
    create_list(:budget_investment, 2, :winner, heading: heading_new)

    visit budget_investments_path(budget_new, heading_id: heading_new.id)

    options = find("#filter_selector").all("option").map { |option| option.text.strip }
    expect(options).to eq ["Not unfeasible", "Feasible", "Unfeasible", "Unselected", "Selected", "Winners"]

    select "Feasible", from: "filter_selector"
    feasible_path = budget_investments_path(budget_new, heading_id: heading_new.id,
                                                        filter: "feasible", page: "1")
    expect(page).to have_current_path(feasible_path)
    expect(page).to have_css(".budget-investment", count: 8)

    select "Unfeasible", from: "filter_selector"
    unfeasible_path = budget_investments_path(budget_new, heading_id: heading_new.id,
                                                          filter: "unfeasible", page: "1")
    expect(page).to have_current_path(unfeasible_path)
    expect(page).to have_css(".budget-investment", count: 2)

    select "Unselected", from: "filter_selector"
    unselected_path = budget_investments_path(budget_new, heading_id: heading_new.id,
                                                          filter: "unselected", page: "1")
    expect(page).to have_current_path(unselected_path)
    expect(page).to have_css(".budget-investment", count: 4)

    select "Selected", from: "filter_selector"
    selected_path = budget_investments_path(budget_new, heading_id: heading_new.id,
                                                        filter: "selected", page: "1")
    expect(page).to have_current_path(selected_path)
    expect(page).to have_css(".budget-investment", count: 4)

    select "Winners", from: "filter_selector"
    winners_path = budget_investments_path(budget_new, heading_id: heading_new.id,
                                                       filter: "winners", page: "1")
    expect(page).to have_current_path(winners_path)
    expect(page).to have_css(".budget-investment", count: 2)

    select "Not unfeasible", from: "filter_selector"
    not_unfeasible_path = budget_investments_path(budget_new, heading_id: heading_new.id,
                                                              filter: "not_unfeasible", page: "1")
    expect(page).to have_current_path(not_unfeasible_path)
    expect(page).to have_css(".budget-investment", count: 8)
  end

  context("Search") do
    scenario "Search by text" do
      investment1 = create(:budget_investment, heading: heading, title: "Get Schwifty")
      investment2 = create(:budget_investment, heading: heading, title: "Schwifty Hello")
      investment3 = create(:budget_investment, heading: heading, title: "Do not show me")

      visit budget_investments_path(budget, heading_id: heading.id)

      within(".expanded #search_form") do
        fill_in "search", with: "Schwifty"
        click_button "Search"
      end

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 2)

        expect(page).to have_content(investment1.title)
        expect(page).to have_content(investment2.title)
        expect(page).not_to have_content(investment3.title)
      end
    end

    context "Advanced search" do
      scenario "Search by text", :js do
        bdgt_invest1 = create(:budget_investment, heading: heading, title: "Get Schwifty")
        bdgt_invest2 = create(:budget_investment, heading: heading, title: "Schwifty Hello")
        bdgt_invest3 = create(:budget_investment, heading: heading, title: "Do not show me")

        visit budget_investments_path(budget)

        click_link "Advanced search"
        fill_in "Write the text", with: "Schwifty"
        click_button "Filter"

        expect(page).to have_content("There are 2 investments")

        within("#budget-investments") do
          expect(page).to have_content(bdgt_invest1.title)
          expect(page).to have_content(bdgt_invest2.title)
          expect(page).not_to have_content(bdgt_invest3.title)
        end
      end

      context "Search by author type" do
        scenario "Public employee", :js do
          ana = create :user, official_level: 1
          john = create :user, official_level: 2

          bdgt_invest1 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest2 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest3 = create(:budget_investment, heading: heading, author: john)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select Setting["official_level_1_name"], from: "advanced_search_official_level"
          click_button "Filter"

          expect(page).to have_content("There are 2 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).not_to have_content(bdgt_invest3.title)
          end
        end

        scenario "Municipal Organization", :js do
          ana = create :user, official_level: 2
          john = create :user, official_level: 3

          bdgt_invest1 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest2 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest3 = create(:budget_investment, heading: heading, author: john)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select Setting["official_level_2_name"], from: "advanced_search_official_level"
          click_button "Filter"

          expect(page).to have_content("There are 2 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).not_to have_content(bdgt_invest3.title)
          end
        end

        scenario "General director", :js do
          ana = create :user, official_level: 3
          john = create :user, official_level: 4

          bdgt_invest1 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest2 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest3 = create(:budget_investment, heading: heading, author: john)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select Setting["official_level_3_name"], from: "advanced_search_official_level"
          click_button "Filter"

          expect(page).to have_content("There are 2 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).not_to have_content(bdgt_invest3.title)
          end
        end

        scenario "City councillor", :js do
          ana = create :user, official_level: 4
          john = create :user, official_level: 5

          bdgt_invest1 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest2 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest3 = create(:budget_investment, heading: heading, author: john)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select Setting["official_level_4_name"], from: "advanced_search_official_level"
          click_button "Filter"

          expect(page).to have_content("There are 2 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).not_to have_content(bdgt_invest3.title)
          end
        end

        scenario "Mayoress", :js do
          ana = create :user, official_level: 5
          john = create :user, official_level: 4

          bdgt_invest1 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest2 = create(:budget_investment, heading: heading, author: ana)
          bdgt_invest3 = create(:budget_investment, heading: heading, author: john)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select Setting["official_level_5_name"], from: "advanced_search_official_level"
          click_button "Filter"

          expect(page).to have_content("There are 2 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).not_to have_content(bdgt_invest3.title)
          end
        end
      end

      context "Search by date" do
        context "Predefined date ranges" do
          scenario "Last day", :js do
            bdgt_invest1 = create(:budget_investment, heading: heading, created_at: 1.minute.ago)
            bdgt_invest2 = create(:budget_investment, heading: heading, created_at: 1.hour.ago)
            bdgt_invest3 = create(:budget_investment, heading: heading, created_at: 2.days.ago)

            visit budget_investments_path(budget)

            click_link "Advanced search"
            select "Last 24 hours", from: "js-advanced-search-date-min"
            click_button "Filter"

            expect(page).to have_content("There are 2 investments")

            within("#budget-investments") do
              expect(page).to have_content(bdgt_invest1.title)
              expect(page).to have_content(bdgt_invest2.title)
              expect(page).not_to have_content(bdgt_invest3.title)
            end
          end

          scenario "Last week", :js do
            bdgt_invest1 = create(:budget_investment, heading: heading, created_at: 1.day.ago)
            bdgt_invest2 = create(:budget_investment, heading: heading, created_at: 5.days.ago)
            bdgt_invest3 = create(:budget_investment, heading: heading, created_at: 8.days.ago)

            visit budget_investments_path(budget)

            click_link "Advanced search"
            select "Last week", from: "js-advanced-search-date-min"
            click_button "Filter"

            expect(page).to have_content("There are 2 investments")

            within("#budget-investments") do
              expect(page).to have_content(bdgt_invest1.title)
              expect(page).to have_content(bdgt_invest2.title)
              expect(page).not_to have_content(bdgt_invest3.title)
            end
          end

          scenario "Last month", :js do
            bdgt_invest1 = create(:budget_investment, heading: heading, created_at: 10.days.ago)
            bdgt_invest2 = create(:budget_investment, heading: heading, created_at: 20.days.ago)
            bdgt_invest3 = create(:budget_investment, heading: heading, created_at: 33.days.ago)

            visit budget_investments_path(budget)

            click_link "Advanced search"
            select "Last month", from: "js-advanced-search-date-min"
            click_button "Filter"

            expect(page).to have_content("There are 2 investments")

            within("#budget-investments") do
              expect(page).to have_content(bdgt_invest1.title)
              expect(page).to have_content(bdgt_invest2.title)
              expect(page).not_to have_content(bdgt_invest3.title)
            end
          end

          scenario "Last year", :js do
            bdgt_invest1 = create(:budget_investment, heading: heading, created_at: 300.days.ago)
            bdgt_invest2 = create(:budget_investment, heading: heading, created_at: 350.days.ago)
            bdgt_invest3 = create(:budget_investment, heading: heading, created_at: 370.days.ago)

            visit budget_investments_path(budget)

            click_link "Advanced search"
            select "Last year", from: "js-advanced-search-date-min"
            click_button "Filter"

            expect(page).to have_content("There are 2 investments")

            within("#budget-investments") do
              expect(page).to have_content(bdgt_invest1.title)
              expect(page).to have_content(bdgt_invest2.title)
              expect(page).not_to have_content(bdgt_invest3.title)
            end
          end
        end

        scenario "Search by custom date range", :js do
          bdgt_invest1 = create(:budget_investment, heading: heading, created_at: 2.days.ago)
          bdgt_invest2 = create(:budget_investment, heading: heading, created_at: 3.days.ago)
          bdgt_invest3 = create(:budget_investment, heading: heading, created_at: 9.days.ago)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select "Customized", from: "js-advanced-search-date-min"
          fill_in "advanced_search_date_min", with: 7.days.ago
          fill_in "advanced_search_date_max", with: 1.day.ago
          click_button "Filter"

          expect(page).to have_content("There are 2 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).not_to have_content(bdgt_invest3.title)
          end
        end

        scenario "Search by custom invalid date range", :js do
          bdgt_invest1 = create(:budget_investment, heading: heading, created_at: 2.days.ago)
          bdgt_invest2 = create(:budget_investment, heading: heading, created_at: 3.days.ago)
          bdgt_invest3 = create(:budget_investment, heading: heading, created_at: 9.days.ago)

          visit budget_investments_path(budget)

          click_link "Advanced search"
          select "Customized", from: "js-advanced-search-date-min"
          fill_in "advanced_search_date_min", with: 4000.years.ago
          fill_in "advanced_search_date_max", with: "wrong date"
          click_button "Filter"

          expect(page).to have_content("There are 3 investments")

          within("#budget-investments") do
            expect(page).to have_content(bdgt_invest1.title)
            expect(page).to have_content(bdgt_invest2.title)
            expect(page).to have_content(bdgt_invest3.title)
          end
        end

        scenario "Search by multiple filters", :js do
          ana  = create :user, official_level: 1
          john = create :user, official_level: 1

          create(:budget_investment, heading: heading, title: "Get Schwifty",   author: ana,  created_at: 1.minute.ago)
          create(:budget_investment, heading: heading, title: "Hello Schwifty", author: john, created_at: 2.days.ago)
          create(:budget_investment, heading: heading, title: "Save the forest")

          visit budget_investments_path(budget)

          click_link "Advanced search"
          fill_in "Write the text", with: "Schwifty"
          select Setting["official_level_1_name"], from: "advanced_search_official_level"
          select "Last 24 hours", from: "js-advanced-search-date-min"

          click_button "Filter"

          expect(page).to have_content("There is 1 investment")

          within("#budget-investments") do
            expect(page).to have_content "Get Schwifty"
          end
        end

        scenario "Maintain advanced search criteria", :js do
          visit budget_investments_path(budget)
          click_link "Advanced search"

          fill_in "Write the text", with: "Schwifty"
          select Setting["official_level_1_name"], from: "advanced_search_official_level"
          select "Last 24 hours", from: "js-advanced-search-date-min"

          click_button "Filter"

          expect(page).to have_content("investments cannot be found")

          within "#js-advanced-search" do
            expect(page).to have_selector("input[name='search'][value='Schwifty']")
            expect(page).to have_select("advanced_search[official_level]", selected: Setting["official_level_1_name"])
            expect(page).to have_select("advanced_search[date_min]", selected: "Last 24 hours")
          end
        end

        scenario "Maintain custom date search criteria", :js do
          visit budget_investments_path(budget)
          click_link "Advanced search"

          select "Customized", from: "js-advanced-search-date-min"
          fill_in "advanced_search_date_min", with: 7.days.ago.strftime("%d/%m/%Y")
          fill_in "advanced_search_date_max", with: 1.day.ago.strftime("%d/%m/%Y")
          click_button "Filter"

          expect(page).to have_content("investments cannot be found")

          within "#js-advanced-search" do
            expect(page).to have_select("advanced_search[date_min]", selected: "Customized")
            expect(page).to have_selector("input[name='advanced_search[date_min]'][value*='#{7.days.ago.strftime("%d/%m/%Y")}']")
            expect(page).to have_selector("input[name='advanced_search[date_max]'][value*='#{1.day.ago.strftime("%d/%m/%Y")}']")
          end
        end
      end
    end
  end

  context("Filters") do
    scenario "by unfeasibility" do
      investment1 = create(:budget_investment, :unfeasible, :finished, heading: heading)
      investment2 = create(:budget_investment, :feasible, heading: heading)
      investment3 = create(:budget_investment, heading: heading)
      investment4 = create(:budget_investment, :feasible, heading: heading)

      visit budget_investments_path(budget, heading_id: heading.id, filter: "unfeasible")

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 1)

        expect(page).to have_content(investment1.title)
        expect(page).not_to have_content(investment2.title)
        expect(page).not_to have_content(investment3.title)
        expect(page).not_to have_content(investment4.title)
      end
    end

    context "Results Phase" do
      before { budget.update(phase: "finished", results_enabled: true) }

      scenario "show winners by default" do
        investment1 = create(:budget_investment, :winner, heading: heading)
        investment2 = create(:budget_investment, :selected, heading: heading)

        visit budget_path(budget)
        click_link "See all investments"

        within("#budget-investments") do
          expect(page).to have_css(".budget-investment", count: 1)
          expect(page).to have_content(investment1.title)
          expect(page).not_to have_content(investment2.title)
        end

        visit budget_results_path(budget)

        click_link "See all investments"

        within("#budget-investments") do
          expect(page).to have_css(".budget-investment", count: 1)
          expect(page).to have_content(investment1.title)
          expect(page).not_to have_content(investment2.title)
        end
      end
    end
  end

  context "Orders" do
    before { budget.update(phase: "selecting") }
    let(:per_page) { Budgets::InvestmentsController::PER_PAGE }

    scenario "Default order is confident score" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      budget.investments.order(:id).find_each do |investment|
        investment.update_columns(confidence_score: investment.id)
      end
      expected_order = budget.investments.order(:id).map(&:title).reverse.first(per_page)

      visit budget_investments_path(budget, heading_id: heading.id)

      within(".submenu .is-active") { expect(page).to have_content "highest rated" }
      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty
      expect(order).to eq expected_order

      visit budget_investments_path(budget, heading_id: heading.id)
      new_order = all(".budget-investment h3").map(&:text)

      expect(order).to eq(new_order)
    end

    scenario "Random order after another order" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, heading_id: heading.id)
      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      click_link "highest rated"
      click_link "random"

      visit budget_investments_path(budget, heading_id: heading.id)
      new_order = all(".budget-investment h3").map(&:text)

      expect(order).to eq(new_order)
    end

    scenario "Random order maintained with pagination" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, heading_id: heading.id)

      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      click_link "Next"
      expect(page).to have_content "You're on page 2"

      click_link "Previous"
      expect(page).to have_content "You're on page 1"

      new_order = all(".budget-investment h3").map(&:text)
      expect(order).to eq(new_order)
    end

    scenario "Random order maintained when going back from show" do
      per_page.times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, heading_id: heading.id)

      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      click_link Budget::Investment.first.title
      click_link "Go back"

      new_order = all(".budget-investment h3").map(&:text)
      expect(order).to eq(new_order)
    end

    scenario "Investments are not repeated with random order" do
      (per_page + 2).times { create(:budget_investment, heading: heading) }

      visit budget_investments_path(budget, order: "random")

      first_page_investments = investments_order

      click_link "Next"
      expect(page).to have_content "You're on page 2"

      second_page_investments = investments_order

      common_values = first_page_investments & second_page_investments

      expect(common_values.length).to eq(0)
    end

    scenario "Proposals are ordered by confidence_score" do
      best_proposal = create(:budget_investment, heading: heading, title: "Best proposal")
      best_proposal.update_column(:confidence_score, 10)
      worst_proposal = create(:budget_investment, heading: heading, title: "Worst proposal")
      worst_proposal.update_column(:confidence_score, 2)
      medium_proposal = create(:budget_investment, heading: heading, title: "Medium proposal")
      medium_proposal.update_column(:confidence_score, 5)

      visit budget_investments_path(budget, heading_id: heading.id)
      click_link "highest rated"
      expect(page).to have_selector("a.is-active", text: "highest rated")

      within "#budget-investments" do
        expect(best_proposal.title).to appear_before(medium_proposal.title)
        expect(medium_proposal.title).to appear_before(worst_proposal.title)
      end

      expect(current_url).to include("order=confidence_score")
      expect(current_url).to include("page=1")
    end

    scenario "Each user has a different and consistent random budget investment order" do
      (per_page * 1.3).to_i.times { create(:budget_investment, heading: heading) }
      first_user_investments_order = nil
      second_user_investments_order = nil

      in_browser(:one) do
        visit budget_investments_path(budget, heading: heading)
        click_link "random"
        first_user_investments_order = investments_order
      end

      in_browser(:two) do
        visit budget_investments_path(budget, heading: heading)
        click_link "random"
        second_user_investments_order = investments_order
      end

      expect(first_user_investments_order).not_to eq(second_user_investments_order)

      in_browser(:one) do
        click_link "Next"
        expect(page).to have_content "You're on page 2"

        click_link "Previous"
        expect(page).to have_content "You're on page 1"

        expect(investments_order).to eq(first_user_investments_order)
      end

      in_browser(:two) do
        click_link "Next"
        expect(page).to have_content "You're on page 2"

        click_link "Previous"
        expect(page).to have_content "You're on page 1"

        expect(investments_order).to eq(second_user_investments_order)
      end
    end

    scenario "Each user has a equal and consistent budget investment order when the random_seed is equal" do
      (per_page * 1.3).to_i.times { create(:budget_investment, heading: heading) }

      first_user_investments_order = nil
      second_user_investments_order = nil

      in_browser(:one) do
        visit budget_investments_path(budget, heading: heading, random_seed: "1")
        first_user_investments_order = investments_order
      end

      in_browser(:two) do
        visit budget_investments_path(budget, heading: heading, random_seed: "1")
        second_user_investments_order = investments_order
      end

      expect(first_user_investments_order).to eq(second_user_investments_order)
    end

    scenario "Set votes for investments randomized with a seed" do
      voter = create(:user, :level_two)

      per_page.times { create(:budget_investment, heading: heading) }

      voted_investments = Array.new(per_page) do
        create(:budget_investment, heading: heading, voters: [voter])
      end

      login_as(voter)
      visit budget_investments_path(budget, heading_id: heading.id)

      voted_investments.each do |investment|
        if page.has_link?(investment.title)
          within("#budget_investment_#{investment.id}") do
            expect(page).to have_content "You have already supported this investment"
          end
        end
      end
    end

    scenario "Order is random if budget is finished" do
      per_page.times { create(:budget_investment, :winner, heading: heading) }

      budget.update!(phase: "finished")

      visit budget_investments_path(budget, heading_id: heading.id)
      order = all(".budget-investment h3").map(&:text)
      expect(order).not_to be_empty

      visit budget_investments_path(budget, heading_id: heading.id)
      new_order = all(".budget-investment h3").map(&:text)

      expect(order).to eq(new_order)
    end

    scenario "Order always is random for unfeasible and unselected investments" do
      Budget::Phase::PHASE_KINDS.each do |phase|
        budget.update!(phase: phase)

        visit budget_investments_path(budget, heading_id: heading.id, filter: "unfeasible")

        within(".submenu") do
          expect(page).to have_content "random"
          expect(page).not_to have_content "by price"
          expect(page).not_to have_content "highest rated"
        end

        visit budget_investments_path(budget, heading_id: heading.id, filter: "unselected")

        within(".submenu") do
          expect(page).to have_content "random"
          expect(page).not_to have_content "price"
          expect(page).not_to have_content "highest rated"
        end
      end
    end

    def investments_order
      all(".budget-investment h3").map(&:text)
    end
  end

  context "Phase I - Accepting" do
    before { budget.update(phase: "accepting") }

    scenario "Create with invisible_captcha honeypot field" do
      login_as(author)
      visit new_budget_investment_path(budget)

      expect(page).to have_selector("input[name=\"budget_investment[heading_id]\"][value=\"#{heading.id}\"]",
                                     visible: false)

      fill_in "Title", with: "I am a bot"
      fill_in "budget_investment_subtitle", with: "This is the honeypot"
      fill_in "Description", with: "This is the description"
      # Check terms of service by default
      # check "I agree to the Privacy Policy and the Terms and conditions of use"

      click_button "Create Investment"

      expect(page.status_code).to eq(200)
      expect(page.html).to be_empty
      expect(page).to have_current_path(budget_investments_path(budget))
    end

    scenario "Create budget investment too fast" do
      allow(InvisibleCaptcha).to receive(:timestamp_threshold).and_return(Float::INFINITY)

      login_as(author)
      visit new_budget_investment_path(budget)

      expect(page).to have_selector("input[name=\"budget_investment[heading_id]\"][value=\"#{heading.id}\"]",
                                     visible: false)

      fill_in "Title", with: "I am a bot"
      fill_in "Description", with: "This is the description"
      # Check terms of service by default
      # check "I agree to the Privacy Policy and the Terms and conditions of use"

      click_button "Create Investment"

      expect(page).to have_content "Sorry, that was too quick! Please resubmit"
      expect(page).to have_current_path(new_budget_investment_path(budget))
    end

    scenario "Create with single heading" do
      login_as(author)

      visit new_budget_investment_path(budget)

      expect(page).to have_content("Describe the idea. Think for example of:")
      expect(page).to have_content("Why is it a good idea?")
      expect(page).to have_content("For whom is the idea meant (e.g. older people, young people, everyone)?")
      expect(page).to have_content("Is it once-only (like an activity) or for several years "\
                                   "(like a facility)?")
      expect(page).to have_content("How much money do you think you will need for it? (optional, "\
                                   "estimation is also fine)")
      expect(page).to have_content("What would you like to do yourself for the realization of the idea?")

      expect(page).to have_content("#{heading.name} (#{budget.formatted_heading_price(heading)})")

      expect(page).to have_selector("input[name=\"budget_investment[heading_id]\"][value=\"#{heading.id}\"]",
                                     visible: false)

      fill_in "Title", with: "Build a skyscraper"
      fill_in "Description", with: "I want to live in a high tower over the clouds"
      fill_in "Information about the location", with: "City center"
      fill_in "If you are proposing in the name of a collective/organization, "\
              "or on behalf of more people, write its name", with: "T.I.A."
      fill_in "Tags", with: "Towers"
      # Check terms of service by default
      # check "I agree to the Privacy Policy and the Terms and conditions of use"

      click_button "Create Investment"

      expect(page).to have_content "Investment created successfully"
      expect(page).to have_content "Build a skyscraper"
      expect(page).to have_content "I want to live in a high tower over the clouds"
      expect(page).to have_content "City center"
      expect(page).to have_content "T.I.A."
      expect(page).to have_content "Towers"

      visit user_url(author, filter: :budget_investments)
      expect(page).to have_content "1 Investment"
      expect(page).to have_content "Build a skyscraper"
    end

    scenario "Create with single heading and hidden money" do
      budget_hide_money = create(:budget, :hide_money)
      group = create(:budget_group, budget: budget_hide_money)
      create(:budget_heading, name: "Heading without money", group: group)

      login_as(author)

      visit new_budget_investment_path(budget_hide_money)

      expect(page).to have_content "Heading without money"
      expect(page).not_to have_content "€"
    end

    scenario "Create with single group and multiple headings" do
      budget = create(:budget)
      group = create(:budget_group, name: "New group", budget: budget)
      create(:budget_heading, budget: budget, group: group, name: "Culture")
      create(:budget_heading, budget: budget, group: group, name: "Environment")

      login_as(author)

      visit new_budget_investment_path(budget)

      expect(page).not_to have_content "New group"
      select_options = find("#budget_investment_heading_id").all("option").map(&:text)
      expect(select_options).to eq ["", "Culture", "Environment"]
    end

    scenario "Create with multiple headings" do
      heading2 = create(:budget_heading, budget: budget, group: group)
      heading3 = create(:budget_heading, budget: budget)
      login_as(author)

      visit new_budget_investment_path(budget)

      expect(page).to have_content("Describe the idea. Think for example of:")
      expect(page).to have_content("Why is it a good idea?")
      expect(page).to have_content("For whom is the idea meant (e.g. older people, young people, everyone)?")
      expect(page).to have_content("Is it once-only (like an activity) or for several years "\
                                   "(like a facility)?")
      expect(page).to have_content("How much money do you think you will need for it? (optional, "\
                                   "estimation is also fine)")
      expect(page).to have_content("What would you like to do yourself for the realization of the idea?")

      expect(page).not_to have_content("#{heading.name} (#{budget.formatted_heading_price(heading)})")

      within("#budget_investment_heading_id") do
        expect(page).to have_selector("option[value='#{heading.id}']")
        expect(page).to have_selector("option[value='#{heading2.id}']")
        expect(page).to have_selector("option[value='#{heading3.id}']")
      end

      select "#{group.name}: #{heading2.name}", from: "budget_investment_heading_id"
      fill_in "Title", with: "Build a skyscraper"
      fill_in "Description", with: "I want to live in a high tower over the clouds"
      fill_in "budget_investment_location", with: "City center"
      fill_in "budget_investment_organization_name", with: "T.I.A."
      fill_in "budget_investment_tag_list", with: "Towers"
      # Check terms of service by default
      # check "budget_investment_terms_of_service"

      click_button "Create Investment"

      expect(page).to have_content "Investment created successfully"
      expect(page).to have_content "Build a skyscraper"
      expect(page).to have_content "I want to live in a high tower over the clouds"
      expect(page).to have_content "City center"
      expect(page).to have_content "T.I.A."
      expect(page).to have_content "Towers"

      visit user_url(author, filter: :budget_investments)
      expect(page).to have_content "1 Investment"
      expect(page).to have_content "Build a skyscraper"
    end

    scenario "Edit", :js do
      daniel = create(:user, :level_two)

      create(:budget_investment, heading: heading, title: "Get Schwifty", author: daniel, created_at: 1.day.ago)

      login_as(daniel)

      visit user_path(daniel, filter: "budget_investments")

      click_link("Edit", match: :first)
      fill_in "Title", with: "Park improvements"
      # Check terms of service by default
      # check "budget_investment_terms_of_service"

      click_button "Update Investment"

      expect(page).to have_content "Investment project updated succesfully"
      expect(page).to have_content "Park improvements"
    end

    scenario "Trigger validation errors in edit view" do
      daniel = create(:user, :level_two)
      message_error = "is too short (minimum is 4 characters), can't be blank"
      create(:budget_investment, heading: heading, title: "Get SH", author: daniel, created_at: 1.day.ago)

      login_as(daniel)

      visit user_path(daniel, filter: "budget_investments")
      click_link("Edit", match: :first)
      fill_in "Title", with: ""
      # Check terms of service by default
      # check "budget_investment_terms_of_service"

      click_button "Update Investment"

      expect(page).to have_content message_error
    end

    scenario "Another User can't edit budget investment" do
      message_error = "You do not have permission to carry out the action 'edit' on budget/investment"
      admin = create(:administrator)
      daniel = create(:user, :level_two)
      investment = create(:budget_investment, heading: heading, author: daniel)

      login_as(admin.user)
      visit edit_budget_investment_path(budget, investment)

      expect(page).to have_content message_error
    end

    scenario "Errors on create" do
      login_as(author)

      visit new_budget_investment_path(budget)
      click_button "Create Investment"
      expect(page).to have_content error_message
    end

    context "Suggest" do
      factory = :budget_investment

      scenario "Show up to 5 suggestions", :js do
        %w[first second third fourth fifth sixth].each do |ordinal|
          create(factory, title: "#{ordinal.titleize} #{factory}, has search term", budget: budget)
        end
        create(factory, title: "This is the last #{factory}", budget: budget)

        login_as(author)
        visit new_budget_investment_path(budget)
        fill_in "Title", with: "search"

        within("div.js-suggest") do
          expect(page).to have_content "You are seeing 5 of 6 investments containing the term 'search'"
        end
      end

      scenario "No found suggestions", :js do
        %w[first second third fourth fifth sixth].each do |ordinal|
          create(factory, title: "#{ordinal.titleize} #{factory}, has search term", budget: budget)
        end

        login_as(author)
        visit new_budget_investment_path(budget)
        fill_in "Title", with: "item"

        within("div.js-suggest") do
          expect(page).not_to have_content "You are seeing"
        end
      end

      scenario "Don't show suggestions from a different budget", :js do
        %w[first second third fourth fifth sixth].each do |ordinal|
          create(factory, title: "#{ordinal.titleize} #{factory}, has search term", budget: budget)
        end

        login_as(author)
        visit new_budget_investment_path(other_budget)
        fill_in "Title", with: "search"

        within("div.js-suggest") do
          expect(page).not_to have_content "You are seeing"
        end
      end
    end

    scenario "Ballot is not visible" do
      login_as(author)

      visit budget_investments_path(budget, heading_id: heading.id)

      expect(page).not_to have_link("Submit my ballot")
      expect(page).not_to have_css("#progress_bar")

      within("#sidebar") do
        expect(page).not_to have_content("My ballot")
        expect(page).not_to have_link("Submit my ballot")
      end
    end

    scenario "Heading options are correctly ordered" do
      city_group = create(:budget_group, name: "Toda la ciudad", budget: budget)
      create(:budget_heading, name: "Toda la ciudad", price: 333333, group: city_group)
      create(:budget_heading, name: "More health professionals", price: 999999, group: group)

      login_as(author)

      visit new_budget_investment_path(budget)

      select_options = find("#budget_investment_heading_id").all("option").map(&:text)
      expect(select_options).to eq ["",
                                    "Toda la ciudad: Toda la ciudad",
                                    "Health: More health professionals",
                                    "Health: More hospitals"]
    end
  end

  scenario "Show" do
    investment = create(:budget_investment, heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content(investment.title)
    expect(page).to have_content(investment.description)
    expect(page).to have_content(investment.author.name)
    expect(page).to have_content(investment.comments_count)
    expect(page).to have_content(investment.heading.name)
    # Remove investment code
    # within("#investment_code") do
    #   expect(page).to have_content(investment.id)
    # end
  end

  context "Show Investment's price & cost explanation" do
    let(:investment) { create(:budget_investment, :selected_with_price, heading: heading) }

    context "When investment with price is selected" do
      scenario "Price & explanation is shown when Budget is on published prices phase" do
        Budget::Phase::PUBLISHED_PRICES_PHASES.each do |phase|
          budget.update!(phase: phase)
          visit budget_investment_path(budget, id: investment.id)

          expect(page).to have_content(investment.formatted_price)
          expect(page).to have_content(investment.price_explanation)
          expect(page).to have_link("See price explanation")

          if budget.finished?
            investment.update(winner: true)
          end

          visit budget_investments_path(budget)

          expect(page).to have_content(investment.formatted_price)
        end
      end

      scenario "Price & explanation isn't shown when Budget is not on published prices phase" do
        (Budget::Phase::PHASE_KINDS - Budget::Phase::PUBLISHED_PRICES_PHASES).each do |phase|
          budget.update!(phase: phase)
          visit budget_investment_path(budget, id: investment.id)

          expect(page).not_to have_content(investment.formatted_price)
          expect(page).not_to have_content(investment.price_explanation)
          expect(page).not_to have_link("See price explanation")

          visit budget_investments_path(budget)

          expect(page).not_to have_content(investment.formatted_price)
        end
      end
    end

    context "When investment with price is unselected" do
      before do
        investment.update(selected: false)
      end

      scenario "Price & explanation isn't shown for any Budget's phase" do
        Budget::Phase::PHASE_KINDS.each do |phase|
          budget.update!(phase: phase)
          visit budget_investment_path(budget, id: investment.id)

          expect(page).not_to have_content(investment.formatted_price)
          expect(page).not_to have_content(investment.price_explanation)
          expect(page).not_to have_link("See price explanation")

          visit budget_investments_path(budget)

          expect(page).not_to have_content(investment.formatted_price)
        end
      end
    end
  end

  scenario "Can access the community" do
    Setting["feature.community"] = true

    investment = create(:budget_investment, heading: heading)
    visit budget_investment_path(budget, id: investment.id)
    expect(page).to have_content "Access the community"
  end

  scenario "Can not access the community" do
    Setting["feature.community"] = false

    investment = create(:budget_investment, heading: heading)
    visit budget_investment_path(budget, id: investment.id)
    expect(page).not_to have_content "Access the community"
  end

  scenario "Don't display flaggable buttons" do
    investment = create(:budget_investment, heading: heading)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_selector ".js-follow"
  end

  scenario "Show back link contains heading id" do
    investment = create(:budget_investment, heading: heading)
    visit budget_investment_path(budget, investment)

    expect(page).to have_link "Go back", href: budget_investments_path(budget, heading_id: investment.heading)
  end

  context "Show (feasible budget investment)" do
    let(:investment) do
      create(:budget_investment,
             :feasible,
             :finished,
             budget: budget,
             heading: heading,
             price: 16,
             price_explanation: "Every wheel is 4 euros, so total is 16")
    end

    before do
      user = create(:user)
      login_as(user)
    end

    scenario "Budget in selecting phase" do
      budget.update!(phase: "selecting")
      visit budget_investment_path(budget, id: investment.id)

      expect(page).not_to have_content("Unfeasibility explanation")
      expect(page).not_to have_content("Price explanation")
      expect(page).not_to have_content(investment.price_explanation)
    end
  end

  scenario "Show (unfeasible budget investment) only when valuation finished" do
    investment = create(:budget_investment,
                        :unfeasible,
                        budget: budget,
                        heading: heading,
                        unfeasibility_explanation: "Local government is not competent in this")

    investment_2 = create(:budget_investment,
                        :unfeasible,
                        :finished,
                        budget: budget,
                        heading: heading,
                        unfeasibility_explanation: "The unfeasible explanation")

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_content("Unfeasibility explanation")
    expect(page).not_to have_content("Local government is not competent in this")
    expect(page).not_to have_content("This investment project has been marked as not feasible "\
                                     "and will not go to balloting phase")

    visit budget_investment_path(budget, id: investment_2.id)

    expect(page).to have_content("Unfeasibility explanation")
    expect(page).to have_content("The unfeasible explanation")
    expect(page).to have_content("This investment project has been marked as not feasible "\
                                 "and will not go to balloting phase")
  end

  scenario "Show feasible explanation only when valuation finished" do
    investment = create(:budget_investment, :feasible, budget: budget, heading: heading,
                        feasibility_explanation: "Local government is competent in this")

    investment_2 = create(:budget_investment, :feasible, :finished, budget: budget, heading: heading,
                          feasibility_explanation: "The feasible explanation")

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, investment)

    expect(page).not_to have_content("Feasibility explanation")
    expect(page).not_to have_content("Local government is competent in this")

    visit budget_investment_path(budget, investment_2)

    expect(page).to have_content("Feasibility explanation")
    expect(page).to have_content("The feasible explanation")
  end

  scenario "Show (selected budget investment)" do
    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        :selected,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content("This investment project has been selected for balloting phase")
  end

  scenario "Show (winner budget investment) only if budget is finished" do
    budget.update!(phase: "balloting")

    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        :selected,
                        :winner,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_content("Winning investment project")

    budget.update!(phase: "finished")

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content("Winning investment project")
  end

  scenario "Show (not selected budget investment)" do
    budget.update!(phase: "balloting")

    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).to have_content("This investment project has not been selected for balloting phase")
  end

  scenario "Show title (no message)" do
    skip "Removed by custom content"
    investment = create(:budget_investment,
                        :feasible,
                        :finished,
                        budget: budget,
                        heading: heading)

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    within("aside") do
      expect(page).to have_content("Investment project")
      expect(page).to have_css(".label-budget-investment")
    end
  end

  scenario "Show (unfeasible budget investment with valuation not finished)" do
    investment = create(:budget_investment,
                        :unfeasible,
                        :open,
                        budget: budget,
                        heading: heading,
                        unfeasibility_explanation: "Local government is not competent in this matter")

    user = create(:user)
    login_as(user)

    visit budget_investment_path(budget, id: investment.id)

    expect(page).not_to have_content("Unfeasibility explanation")
    expect(page).not_to have_content("Local government is not competent in this matter")
  end

  it_behaves_like "followable", "budget_investment", "budget_investment_path", { "budget_id": "budget_id", "id": "id" }

  it_behaves_like "imageable", "budget_investment", "budget_investment_path", { "budget_id": "budget_id", "id": "id" }

  it_behaves_like "nested imageable",
                  "budget_investment",
                  "new_budget_investment_path",
                  { "budget_id": "budget_id" },
                  "imageable_fill_new_valid_budget_investment",
                  "Create Investment",
                  "Budget Investment created successfully."

  it_behaves_like "documentable", "budget_investment", "budget_investment_path", { "budget_id": "budget_id", "id": "id" }

  it_behaves_like "nested documentable",
                  "user",
                  "budget_investment",
                  "new_budget_investment_path",
                  { "budget_id": "budget_id" },
                  "documentable_fill_new_valid_budget_investment",
                  "Create Investment",
                  "Budget Investment created successfully."

  it_behaves_like "mappable",
                  "budget_investment",
                  "investment",
                  "new_budget_investment_path",
                  "",
                  "budget_investment_path",
                  { "budget_id": "budget_id" }

  context "Destroy" do
    scenario "Admin cannot destroy budget investments" do
      user = create(:user, :level_two)
      investment = create(:budget_investment, heading: heading, author: user)

      login_as(create(:administrator).user)
      visit user_path(user)

      within("#budget_investment_#{investment.id}") do
        expect(page).not_to have_link "Delete"
      end
    end

    scenario "Author can destroy while on the accepting phase" do
      user = create(:user, :level_two)
      investment1 = create(:budget_investment, heading: heading, price: 10000, author: user)

      login_as(user)
      visit user_path(user, tab: :budget_investments)

      within("#budget_investment_#{investment1.id}") do
        expect(page).to have_content(investment1.title)
        click_link("Delete")
      end

      visit user_path(user, tab: :budget_investments)
    end
  end

  context "Selecting Phase" do
    before do
      budget.update(phase: "selecting")
    end

    context "Popup alert to vote only in one heading per group" do
      scenario "When supporting in the first heading group", :js do
        carabanchel = create(:budget_heading, group: group)
        salamanca   = create(:budget_heading, group: group)

        create(:budget_investment, :selected, title: "In Carabanchel", heading: carabanchel)
        create(:budget_investment, :selected, title: "In Salamanca", heading: salamanca)

        login_as(author)
        visit budget_investments_path(budget, heading_id: carabanchel.id)

        within(".budget-investment", text: "In Carabanchel") do
          expect(page).to have_css(".in-favor a[data-confirm]")
        end
      end

      scenario "When already supported in the group", :js do
        carabanchel = create(:budget_heading, group: group)
        salamanca   = create(:budget_heading, group: group)

        create(:budget_investment, title: "In Carabanchel", heading: carabanchel, voters: [author])
        create(:budget_investment, title: "In Salamanca", heading: salamanca)

        login_as(author)
        visit budget_investments_path(budget, heading_id: carabanchel.id)

        within(".budget-investment", text: "In Carabanchel") do
          expect(page).not_to have_css(".in-favor a[data-confirm]")
        end
      end

      scenario "When supporting in another group", :js do
        heading = create(:budget_heading, group: group)

        group2 = create(:budget_group, budget: budget)
        another_heading1 = create(:budget_heading, group: group2)

        create(:budget_heading, group: group2)
        create(:budget_investment, heading: heading, title: "Investment", voters: [author])
        create(:budget_investment, heading: another_heading1, title: "Another investment")

        login_as(author)
        visit budget_investments_path(budget, heading_id: another_heading1.id)

        within(".budget-investment", text: "Another investment") do
          expect(page).to have_css(".in-favor a[data-confirm]")
        end
      end

      scenario "When supporting in a group with a single heading", :js do
        all_city_investment = create(:budget_investment, heading: heading)

        login_as(author)
        visit budget_investments_path(budget, heading_id: heading.id)

        within("#budget_investment_#{all_city_investment.id}") do
          expect(page).not_to have_css(".in-favor a[data-confirm]")
        end
      end
    end

    scenario "Sidebar in show should display support text" do
      investment = create(:budget_investment, budget: budget)
      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "Supports"
      end
    end

    scenario "Is possible to remove a support from show view", :js do
      investment = create(:budget_investment, budget: budget)

      login_as(author)
      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "No supports"
        click_link "Support"
      end

      expect(page).to have_content "You have already supported this investment project."

      within("aside") do
        expect(page).to have_content "1 support"
        click_link "Remove your support"
      end

      expect(page).to have_content "No supports"
      within("aside") { expect(page).to have_link "Support" }
    end

    scenario "Is possible to remove a support from list view", :js do
      investment = create(:budget_investment, budget: budget)

      login_as(author)
      visit budget_investments_path(budget)

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "No supports"
        click_link "Support"
      end

      expect(page).to have_content "You have already supported this investment project."

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "1 support"
        click_link "Remove your support"
      end

      expect(page).to have_content "No supports"
      within("#budget_investment_#{investment.id}") { expect(page).to have_link "Support" }
    end
  end

  context "Evaluating Phase" do
    before do
      budget.update(phase: "valuating")
    end

    scenario "Sidebar in show should display support text and count" do
      investment = create(:budget_investment, :selected, budget: budget, voters: [create(:user)])

      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "Supports"
        expect(page).to have_content "1 support"
      end
    end

    scenario "Index should display support count" do
      investment = create(:budget_investment, budget: budget, heading: heading, voters: [create(:user)])

      visit budget_investments_path(budget, heading_id: heading.id)

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "1 support"
      end
    end

    scenario "Show should display support text and count" do
      investment = create(:budget_investment, budget: budget, heading: heading, voters: [create(:user)])

      visit budget_investment_path(budget, investment)

      within("#budget_investment_#{investment.id}") do
        expect(page).to have_content "Supports"
        expect(page).to have_content "1 support"
      end
    end
  end

  context "Publishing prices phase" do
    before do
      budget.update(phase: "publishing_prices")
    end

    scenario "Heading index - should show only selected investments" do
      investment1 = create(:budget_investment, :selected, heading: heading, price: 10000)
      investment2 = create(:budget_investment, :selected, heading: heading, price: 15000)
      investment3 = create(:budget_investment, heading: heading, price: 30000)

      visit budget_investments_path(budget, heading: heading)

      within("#budget-investments") do
        expect(page).to have_content investment1.title
        expect(page).to have_content investment2.title
        expect(page).not_to have_content investment3.title
      end
    end
  end

  context "Balloting Phase" do
    before do
      budget.update(phase: "balloting")
    end

    scenario "Index" do
      user = create(:user, :level_two)
      investment1 = create(:budget_investment, :selected, heading: heading, price: 10000)
      investment2 = create(:budget_investment, :selected, heading: heading, price: 20000)

      login_as(user)
      visit root_path

      first(:link, "Participatory budgeting").click

      click_link "See all investments"

      within("#budget_investment_#{investment1.id}") do
        expect(page).to have_content investment1.title
        expect(page).to have_content "€10,000"
      end

      within("#budget_investment_#{investment2.id}") do
        expect(page).to have_content investment2.title
        expect(page).to have_content "€20,000"
      end
    end

    scenario "Order by cost (only when balloting)" do
      mid_investment = create(:budget_investment, :selected, heading: heading, title: "Build a nice house", price: 1000)
      mid_investment.update_column(:confidence_score, 10)
      low_investment = create(:budget_investment, :selected, heading: heading, title: "Build an ugly house", price: 1000)
      low_investment.update_column(:confidence_score, 5)
      high_investment = create(:budget_investment, :selected, heading: heading, title: "Build a skyscraper", price: 20000)

      visit budget_investments_path(budget, heading_id: heading.id)

      click_link "by price"
      expect(page).to have_selector("a.is-active", text: "by price")

      within "#budget-investments" do
        expect(high_investment.title).to appear_before(mid_investment.title)
        expect(mid_investment.title).to appear_before(low_investment.title)
      end

      expect(current_url).to include("order=price")
      expect(current_url).to include("page=1")
    end

    scenario "Show" do
      user = create(:user, :level_two)
      investment = create(:budget_investment, :selected, heading: heading, price: 10000)

      login_as(user)
      visit budget_investments_path(budget, heading_id: heading.id)

      click_link investment.title

      expect(page).to have_content "€10,000"
    end

    scenario "Show message if user already voted in other heading" do
      group = create(:budget_group, budget: budget, name: "Global Group")
      heading = create(:budget_heading, group: group, name: "Heading 1")
      investment = create(:budget_investment, :selected, heading: heading)
      heading2 = create(:budget_heading, group: group, name: "Heading 2")
      investment2 = create(:budget_investment, :selected, heading: heading2)
      user = create(:user, :level_two, ballot_lines: [investment])

      login_as(user)
      visit budget_investment_path(budget, investment2)

      expect(page).to have_selector(".participation-not-allowed",
                                    text: "You have already voted a different heading: Heading 1",
                                    visible: false)
    end

    scenario "Sidebar in show should display vote text" do
      investment = create(:budget_investment, :selected, budget: budget)
      visit budget_investment_path(budget, investment)

      within("aside") do
        expect(page).to have_content "Votes"
      end
    end

    scenario "Confirm", :js do
      budget.update!(phase: "balloting")
      budget.phases.balloting.update!(starts_at: "01-10-2020", ends_at: "31-12-2020")
      user = create(:user, :level_two)

      global_group   = create(:budget_group, budget: budget, name: "Global Group")
      global_heading = create(:budget_heading, group: global_group, name: "Global Heading",
                              latitude: -43.145412, longitude: 12.009423)

      carabanchel_heading = create(:budget_heading, group: group, name: "Carabanchel")
      new_york_heading    = create(:budget_heading, group: group, name: "New York",
                                   latitude: -43.223412, longitude: 12.009423)

      create(:budget_investment, :selected, price: 1, heading: global_heading, title: "World T-Shirt")
      create(:budget_investment, :selected, price: 10, heading: global_heading, title: "Eco pens")
      create(:budget_investment, :selected, price: 100, heading: global_heading, title: "Free tablet")
      create(:budget_investment, :selected, price: 1000, heading: carabanchel_heading, title: "Fireworks")
      create(:budget_investment, :selected, price: 10000, heading: carabanchel_heading, title: "Bus pass")
      create(:budget_investment, :selected, price: 100000, heading: new_york_heading, title: "NASA base")

      login_as(user)
      visit budget_path(budget)
      click_link "See all investments"
      click_link "Global Heading €1,000,000"

      add_to_ballot("World T-Shirt")
      add_to_ballot("Eco pens")

      visit budget_path(budget)
      click_link "See all investments"
      click_link "Carabanchel €1,000,000"

      add_to_ballot("Fireworks")
      add_to_ballot("Bus pass")

      expect(page).to have_content "You can change your vote at any time until the 2020-12-31. "\
                                   "No need to spend all the money available."

      visit budget_ballot_path(budget)

      expect(page).to have_content "But you can change your vote at any time "\
                                   "until this phase is closed."

      within("#budget_group_#{global_group.id}") do
        expect(page).to have_content "World T-Shirt"
        expect(page).to have_content "€1"

        expect(page).to have_content "Eco pens"
        expect(page).to have_content "€10"

        expect(page).not_to have_content "Free tablet"
        expect(page).not_to have_content "€100"
      end

      within("#budget_group_#{group.id}") do
        expect(page).to have_content "Fireworks"
        expect(page).to have_content "€1,000"

        expect(page).to have_content "Bus pass"
        expect(page).to have_content "€10,000"

        expect(page).not_to have_content "NASA base"
        expect(page).not_to have_content "€100,000"
      end
    end

    scenario "Highlight voted heading", :js do
      budget.update!(phase: "balloting")
      user = create(:user, :level_two)

      heading_1 = create(:budget_heading, group: group, name: "Heading 1")
      heading_2 = create(:budget_heading, group: group, name: "Heading 2")

      create(:budget_investment, :selected, heading: heading_1, title: "Zero-emission zone")

      login_as(user)
      visit budget_path(budget)

      click_link "See all investments"
      click_link "Heading 1 €1,000,000"

      add_to_ballot("Zero-emission zone")

      visit budget_group_path(budget, group)

      expect(page).to have_css("#budget_heading_#{heading_1.id}.is-active")
      expect(page).to have_css("#budget_heading_#{heading_2.id}")

    end

    scenario "Ballot is visible" do
      login_as(author)

      visit budget_investments_path(budget, heading_id: heading.id)

      expect(page).to have_link("Submit my ballot")
      expect(page).to have_css("#progress_bar")

      within("#sidebar") do
        expect(page).to have_content("My ballot")
        expect(page).to have_link("Submit my ballot")
      end
    end

    scenario "Show unselected budget investments" do
      investment1 = create(:budget_investment, :unselected, :feasible, :finished, heading: heading)
      investment2 = create(:budget_investment, :selected,   :feasible, :finished, heading: heading)
      investment3 = create(:budget_investment, :selected,   :feasible, :finished, heading: heading)
      investment4 = create(:budget_investment, :selected,   :feasible, :finished, heading: heading)

      visit budget_investments_path(budget, heading_id: heading.id, filter: "unselected")

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 1)

        expect(page).to have_content(investment1.title)
        expect(page).not_to have_content(investment2.title)
        expect(page).not_to have_content(investment3.title)
        expect(page).not_to have_content(investment4.title)
      end
    end

    scenario "Do not display vote button for unselected investments in index" do
      investment = create(:budget_investment, :unselected, heading: heading)

      visit budget_investments_path(budget, heading_id: heading.id, filter: "unselected")

      expect(page).to have_content investment.title
      expect(page).not_to have_link("Vote")
    end

    scenario "Do not display vote button for unselected investments in show" do
      investment = create(:budget_investment, :unselected, heading: heading)

      visit budget_investment_path(budget, investment)

      expect(page).to have_content investment.title
      expect(page).not_to have_link("Vote")
    end

    describe "Reclassification" do
      scenario "Due to heading change" do
        investment = create(:budget_investment, :selected, heading: heading)
        user = create(:user, :level_two, ballot_lines: [investment])
        heading2 = create(:budget_heading, group: group)

        login_as(user)
        visit budget_ballot_path(budget)

        expect(page).to have_content("You have voted one investment")

        investment.heading = heading2
        investment.save!

        visit budget_ballot_path(budget)

        expect(page).to have_content("You have voted 0 investment")
      end

      scenario "Due to being unfeasible" do
        investment = create(:budget_investment, :selected, heading: heading)
        user = create(:user, :level_two, ballot_lines: [investment])

        login_as(user)
        visit budget_ballot_path(budget)

        expect(page).to have_content("You have voted one investment")

        investment.feasibility = "unfeasible"
        investment.unfeasibility_explanation = "too expensive"
        investment.save!

        visit budget_ballot_path(budget)

        expect(page).to have_content("You have voted 0 investment")
      end
    end
  end

  context "sidebar map" do
    scenario "Display 6 investment's markers on sidebar map", :js do
      investment1 = create(:budget_investment, heading: heading)
      investment2 = create(:budget_investment, heading: heading)
      investment3 = create(:budget_investment, heading: heading)
      investment4 = create(:budget_investment, heading: heading)
      investment5 = create(:budget_investment, heading: heading)
      investment6 = create(:budget_investment, heading: heading)

      create(:map_location, longitude: 40.1231, latitude: -3.636, investment: investment1)
      create(:map_location, longitude: 40.1232, latitude: -3.635, investment: investment2)
      create(:map_location, longitude: 40.1233, latitude: -3.634, investment: investment3)
      create(:map_location, longitude: 40.1234, latitude: -3.633, investment: investment4)
      create(:map_location, longitude: 40.1235, latitude: -3.632, investment: investment5)
      create(:map_location, longitude: 40.1236, latitude: -3.631, investment: investment6)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 6, visible: false)
      end
    end

    scenario "Display 2 investment's markers on sidebar map", :js do
      investment1 = create(:budget_investment, heading: heading)
      investment2 = create(:budget_investment, heading: heading)

      create(:map_location, longitude: 40.1281, latitude: -3.656, investment: investment1)
      create(:map_location, longitude: 40.1292, latitude: -3.665, investment: investment2)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 2, visible: false)
      end
    end

    scenario "Display only investment's related to the current heading", :js do
      heading_2 = create(:budget_heading, name: "Madrid", group: group)

      investment1 = create(:budget_investment, heading: heading)
      investment2 = create(:budget_investment, heading: heading)
      investment3 = create(:budget_investment, heading: heading)
      investment4 = create(:budget_investment, heading: heading)
      investment5 = create(:budget_investment, heading: heading_2)
      investment6 = create(:budget_investment, heading: heading_2)

      create(:map_location, longitude: 40.1231, latitude: -3.636, investment: investment1)
      create(:map_location, longitude: 40.1232, latitude: -3.685, investment: investment2)
      create(:map_location, longitude: 40.1233, latitude: -3.664, investment: investment3)
      create(:map_location, longitude: 40.1234, latitude: -3.673, investment: investment4)
      create(:map_location, longitude: 40.1235, latitude: -3.672, investment: investment5)
      create(:map_location, longitude: 40.1236, latitude: -3.621, investment: investment6)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 4, visible: false)
      end
    end

    scenario "Do not display investment's, since they're all related to other heading", :js do
      heading_2 = create(:budget_heading, name: "Madrid", group: group)

      investment1 = create(:budget_investment, heading: heading_2)
      investment2 = create(:budget_investment, heading: heading_2)
      investment3 = create(:budget_investment, heading: heading_2)

      create(:map_location, longitude: 40.1255, latitude: -3.644, investment: investment1)
      create(:map_location, longitude: 40.1258, latitude: -3.637, investment: investment2)
      create(:map_location, longitude: 40.1251, latitude: -3.649, investment: investment3)

      visit budget_investments_path(budget, heading_id: heading.id)

      within ".map_location" do
        expect(page).to have_css(".map-icon", count: 0, visible: false)
      end
    end

    scenario "Shows all investments and not only the ones on the current page", :js do
      stub_const("#{Budgets::InvestmentsController}::PER_PAGE", 2)

      3.times do
        create(:map_location, investment: create(:budget_investment, heading: heading))
      end

      visit budget_investments_path(budget, heading_id: heading.id)

      within("#budget-investments") do
        expect(page).to have_css(".budget-investment", count: 2)
      end

      within(".map_location") do
        expect(page).to have_css(".map-icon", count: 3, visible: false)
      end
    end

    context "Author actions section" do
      scenario "Is not shown if investment is not editable or does not have an image" do
        budget.update!(phase: "reviewing")
        investment = create(:budget_investment, heading: heading, author: author)

        login_as(author)
        visit budget_investment_path(budget, investment)

        within("aside") do
          expect(page).not_to have_content "Author"
          expect(page).not_to have_link "Edit"
          expect(page).not_to have_link "Remove image"
        end
      end

      scenario "Contains edit button in the accepting phase" do
        investment = create(:budget_investment, heading: heading, author: author)

        login_as(author)
        visit budget_investment_path(budget, investment)

        within("aside") do
          expect(page).to have_content "Author"
          expect(page).to have_link "Edit"
          expect(page).not_to have_link "Remove image"
        end
      end

      scenario "Do not show edit button in phases different from accepting" do
        budget.update!(phase: "reviewing")
        investment = create(:budget_investment, :with_image, heading: heading, author: author)

        login_as(author)
        visit budget_investment_path(budget, investment)

        within("aside") do
          expect(page).not_to have_content "Author"
          expect(page).not_to have_link "Edit"
        end
      end
    end
  end
end

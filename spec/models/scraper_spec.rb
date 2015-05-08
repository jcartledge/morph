require 'spec_helper'

describe Scraper do
  context "A scraper with a couple of runs" do
    before :each do
      user = User.create
      VCR.use_cassette('scraper_validations', allow_playback_repeats: true) do
        @scraper = user.scrapers.create(name: "my_scraper")
      end
      @time1 = 2.minutes.ago
      @time2 = 1.minute.ago
      @run1 = @scraper.runs.create(finished_at: @time1)
      @run2 = @scraper.runs.create(finished_at: @time2)
      metric1 = Metric.create(utime: 10.2, stime: 2.4, run_id: @run1.id)
      metric2 = Metric.create(utime: 1.3, stime: 3.5, run_id: @run2.id)
    end

    it "#utime" do
      @scraper.utime.should be_within(0.00001).of(11.5)
    end

    it "#stime" do
      @scraper.stime.should be_within(0.00001).of(5.9)
    end

    it "#cpu_time" do
      @scraper.cpu_time.should be_within(0.00001).of(17.4)
    end

    describe "#scraperwiki_shortname" do
      it do
        @scraper.scraperwiki_url = "https://classic.scraperwiki.com/scrapers/australian_rainfall/"
        @scraper.scraperwiki_shortname.should == "australian_rainfall"
      end
    end

    describe "#scraperwiki_url" do
      it do
        @scraper.scraperwiki_shortname = "australian_rainfall"
        @scraper.scraperwiki_url.should == "https://classic.scraperwiki.com/scrapers/australian_rainfall/"
      end

      it do
        @scraper.scraperwiki_shortname = nil
        @scraper.scraperwiki_url.should be_nil
      end

      it do
        @scraper.scraperwiki_shortname = ''
        @scraper.scraperwiki_url.should be_nil
      end
    end

    describe "#latest_successful_run_time" do
      context "The first run is successful" do
        before :each do
          @run1.update_attributes(status_code: 0)
          @run2.update_attributes(status_code: 255)
        end

        it { @scraper.latest_successful_run_time.to_s.should == @time1.to_s }
      end

      context "The second run is successful" do
        before :each do
          @run1.update_attributes(status_code: 255)
          @run2.update_attributes(status_code: 0)
        end

        it { @scraper.latest_successful_run_time.to_s.should == @time2.to_s }
      end

      context "Neither are successful" do
        before :each do
          @run1.update_attributes(status_code: 255)
          @run2.update_attributes(status_code: 255)
        end

        it { @scraper.latest_successful_run_time.should be_nil }
      end

      context "Both are successful" do
        before :each do
          @run1.update_attributes(status_code: 0)
          @run2.update_attributes(status_code: 0)
        end

        it { @scraper.latest_successful_run_time.to_s.should == @time2.to_s }
      end
    end
  end

  describe 'unique names' do
    it 'should not allow duplicate scraper names for a user' do
      user = create :user
      VCR.use_cassette('scraper_validations', allow_playback_repeats: true) do
        create :scraper, name: 'my_scraper', owner: user
        build(:scraper, name: 'my_scraper', owner: user).should_not be_valid
      end
    end

    it 'should allow the same scraper name for a different user' do
      user1 = create :user
      user2 = create :user
      VCR.use_cassette('scraper_validations', allow_playback_repeats: true) do
        create :scraper, name: 'my_scraper', owner: user1
        build(:scraper, name: 'my_scraper', owner: user2).should be_valid
      end
    end
  end

  describe 'ScraperWiki validations' do
    it 'should be invalid if the scraperwiki shortname is not set' do
      VCR.use_cassette('scraper_validations', allow_playback_repeats: true) do
        build(:scraper, scraperwiki_url: 'foobar').should_not be_valid
      end
    end
  end

  describe "#scraped_domains" do
    let(:scraper) { Scraper.new }
    let(:last_run) { mock_model(Run) }

    it "should return an empty array if there is no last run" do
      expect(scraper.scraped_domains).to eq []
    end

    context "there is a last run" do
      before :each do
        allow(scraper).to receive(:last_run).and_return(last_run)
      end

      it "should defer to the last run" do
        result = mock
        expect(last_run).to receive(:scraped_domains).and_return(result)
        expect(scraper.scraped_domains).to eq result
      end
    end
  end

  describe "#download_count_by_owner" do
    let(:scraper) do
      # Doing this to avoid validations getting called
      s = Scraper.new(owner_id: 1)
      s.save(validate: false)
      s
    end
    let(:owner1) { Owner.create }
    let(:owner2) { Owner.create }
    before :each do
      scraper.api_queries.create(owner: owner1)
      scraper.api_queries.create(owner: owner2)
      scraper.api_queries.create(owner: owner2)
    end

    it do
      expect(scraper.download_count_by_owner).to eq [[owner2, 2], [owner1, 1]]
    end
  end
end

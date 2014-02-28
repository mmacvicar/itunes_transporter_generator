require 'yaml'
require 'itunes/transporter'

module Itunes
  module Transporter
    class XMLParser
	      KNOWN_DISPLAY_TARGETS = {'ipad' => 'iOS-iPad', 'iphone_3.5in' => 'iOS-3.5-in', 'iphone_4in' =>'iOS-4-in'}

	      def initialize(xml_metadata)
	      	@xml_metadata = xml_metadata
	      end

	      def objs
	      	@objs ||= Nokogiri::XML(@xml_metadata)
	      end

	      def metadata
	      	objs.remove_namespaces!
	        {
	          :provider => objs.at_xpath('/package/provider').text,
	          :team_id => objs.at_xpath('/package/team_id').text,
	          :vendor_id => objs.at_xpath('/package/software/vendor_id').text,
	          :id_prefix => '',
	          :versions => parse_versions(objs),
	          :achievements => parse_achievements(objs),
	          :leaderboards => parse_leaderboards(objs),
	          :purchases => parse_purchases(objs)
	        }
	      end  

	      def parse_versions(objs)

	        return unless objs.at_xpath('/package/software/software_metadata/versions')

	        [].tap do |versions|
	          objs.search('/package/software/software_metadata/versions/version').each do |dict|
	            version = Version.new
	            version.name = dict.at_xpath('@string').text
	            version.locales = []

	            dict.search('locales/locale').each do |loc|
	              locale = VersionLocale.new
	              locale.name = loc.at_xpath('@name').text
	              locale.title = loc.at_xpath('title').text
	              locale.description = loc.at_xpath('description').text
	              locale.keywords = loc.search('keywords/keyword').collect(&:text)
	              version_whats_new_node = loc.at_xpath('version_whats_new')
	              locale.version_whats_new = version_whats_new_node ? loc.at_xpath('version_whats_new').text : ""
	              software_url_node = loc.at_xpath('software_url')
	              privacy_url_node = loc.at_xpath('privacy_url')
	              support_url_node = loc.at_xpath('support_url')
	              locale.software_url =  software_url_node ? software_url_node.text : ""
	              locale.privacy_url =   privacy_url_node ? privacy_url_node.text : ""
	              locale.support_url =   support_url_node ? support_url_node.text : ""
	              locale.screenshots = []

	              dict.search('software_screenshots/software_screenshot').each do |screenshot_node|
	              	target = screenshot_node.at_xpath('@display_target').text
	              	checksum = screenshot_node.at_xpath('checksum').text
	              	position = screenshot_node.at_xpath('@position').text.to_i
	                raise "Unknown display target for screenshot" unless KNOWN_DISPLAY_TARGETS.values.include?(target)
	                
					screenshot = VersionScreenshot.new
					screenshot.display_target = target
					screenshot.file_name = "#{target.downcase}_#{position}.png"
					screenshot.position = position
					screenshot.locale_name = locale.name
					screenshot.checksum = checksum
					locale.screenshots << screenshot
	                
	              end

	              version.locales << locale
	            end

	            versions << version
	          end
	        end
	      end

	      def parse_achievements(objs)
	        achievements = []
	        
	        if objs.search('/package/software/software_metadata/game_center/achievements')

	          objs.search('/package/software/software_metadata/game_center/achievements/achievement').each do |dict|
	            achievement = Achievement.new
	            achievement.id = dict.at_xpath('achievement_id').text
	            achievement.name = dict.at_xpath('reference_name').text
	            achievement.points = dict.at_xpath('points').text.to_i
	            achievement.hidden = dict.at_xpath('hidden') ? dict.at_xpath('hidden').text == "true" : false
	            achievement.reusable = dict.at_xpath('reusable') ? dict.at_xpath('reusable').text == "true" : false
	            achievement.should_remove = false
	            achievement.locales = []

	            dict.search('locales/locale').each do |loc|
	              locale = AchievementLocale.new
	              locale.name = loc.at_xpath('@name').text
	              locale.title = loc.at_xpath('title').text
	              locale.before_earned_description = loc.at_xpath('before_earned_description').text
	              locale.after_earned_description = loc.at_xpath('after_earned_description').text
	              locale.achievement_after_earned_image = ""
	              locale.should_remove = false

	              achievement.locales << locale
	            end

	            achievements << achievement
	          end
	        end
	        achievements  
	      end

	      def parse_leaderboards(objs)
	        leaderboards = []

	        if objs.search('/package/software/software_metadata/game_center/leaderboards')
	          objs.search('/package/software/software_metadata/game_center/leaderboards/leaderboard').each do |dict|
	            leaderboard = Leaderboard.new
	            leaderboard.default = dict.at_xpath('@default').text == 'true'
	            leaderboard.id = dict.at_xpath('leaderboard_id').text
	            leaderboard.name = dict.at_xpath('reference_name').text
	            leaderboard.aggregate_parent_leaderboard = dict['aggregate_parent_leaderboard']
	            leaderboard.sort_ascending =  dict.at_xpath('sort_ascending') ? dict.at_xpath('sort_ascending').text == "true" : false
	            leaderboard.score_range_min = dict.at_xpath('score_range_min').text.to_i if dict.at_xpath('score_range_min')
	            leaderboard.score_range_max = dict.at_xpath('score_range_max').text.to_i if dict.at_xpath('score_range_max')
	            leaderboard.locales = []

	            dict.search('locales/locale').each do |loc|
	              locale = LeaderboardLocale.new
	              locale.name = loc.at_xpath('@name').text
	              locale.title = loc.at_xpath('title').text
	              locale.formatter_suffix = loc.at_xpath('formatter_suffix').text
	              locale.formatter_suffix_singular = loc.at_xpath('formatter_suffix_singular').text
	              locale.formatter_type = loc.at_xpath('formatter_type').text
	              locale.should_remove = false

	              leaderboard.locales << locale
	            end

	            leaderboards << leaderboard
	          end
	        end

	        leaderboards
	      end

	      def parse_purchases(objs)
	        purchases = []
	        objs.search('/package/software/software_metadata/in_app_purchases/in_app_purchase').each do |pur|

	          purchase = InAppPurchase.new
	          purchase.product_id = pur.at_xpath('product_id').text
	          purchase.reference_name = pur.at_xpath('reference_name').text
	          purchase.type = pur.at_xpath('type').text
	          purchase.review_screenshot_image = { checksum: pur.at_xpath('review_screenshot/checksum').text } if pur.at_xpath('review_screenshot/checksum')
	          purchase.review_notes = pur.at_xpath('review_notes').text if pur.at_xpath('review_notes')
	          purchase.should_remove = false
	          purchase.locales = []
	          purchase.products = []

	          intervals = pur.search('products/product/intervals/interval') || []

	          product = Product.new
	          product.cleared_for_sale = pur.at_xpath('products/product/cleared_for_sale').text == 'true'
	          if intervals.count == 0
	          	product.wholesale_price_tier = pur.at_xpath('products/product/wholesale_price_tier').text
	          end
 
	          product.should_remove = false
	          product.intervals = []

	          pur.search('products/product/intervals/interval').each do |i|
	            interval = Interval.new
	            interval.start_date = i.at_xpath('start_date').text
	            interval.end_date = i.at_xpath('end_date').text if i.at_xpath('end_date')
	            interval.wholesale_price_tier = i.at_xpath('wholesale_price_tier').text if i.at_xpath('wholesale_price_tier')

	            product.intervals << interval
	          end

	          purchase.products << product

	          pur.search('locales/locale').each do |loc|
	            locale = PurchaseLocale.new
	            locale.name = loc.at_xpath('@name').text
	            locale.title = loc.at_xpath('title').text
	            locale.description = loc.at_xpath('description').text
	            locale.publication_name = loc.at_xpath('publication_name').text if loc.at_xpath('publication_name')

	            purchase.locales << locale
	          end

	          purchases << purchase
	        end

	        purchases
	      end
    end
  end
end
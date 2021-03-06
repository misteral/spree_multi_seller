require 'spree/core/validators/email'


module Spree
	class Seller < ActiveRecord::Base
	#attr_accessible :name, :address_1, :address_2, :city, :state, :zip, :country_id, :logo, :banner,
	#   :roc_number, :business_type_id, :establishment_date, :url, :contact_person_name, :contact_person_email, :phone, :paypal_account_email, :category_ids, :termsandconditions, :active, :user_id

	#validates_presence_of :name, :address_2, :city, :state, :country_id#, :business_type_id, :roc_number, :termsandconditions
	#validates_format_of :contact_person_email, :paypal_account_email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email"

		has_and_belongs_to_many :users, :join_table => "spree_seller_users"
		belongs_to  :country
		#belongs_to  :business_type
		has_many    :products, :dependent => :destroy
		#has_many    :stores, :class_name => "Spree::StoreAddress", :dependent => :destroy
		#has_many    :seller_categories, :dependent => :destroy
		#has_many    :taxonomies, :through => :seller_categories
		#has_one     :bank_detail
		has_many    :stock_locations, :dependent => :destroy
		belongs_to  :owner, :class_name => "Spree::User"

		validates :contact_person_email, uniqueness: true, :on => :create
		validates_presence_of :name

		before_save :fill_simple
		after_create  :deliver_welcome_email

		has_attached_file :logo,
      styles: { mini: '100x100>', normal: '300x300>' },
      default_style: :mini,
      url: '/spree/sellers/:id/:style/:basename.:extension',
      path: ':rails_root/public/spree/sellers/:id/:style/:basename.:extension',
      default_url: '/assets/default_seller.png'

		# has_attached_file :banner, :styles => {
		# :small => "100x100>",
		# :medium => "300x300>",
		# :large => "500x500>" },
		# :default_url => "/assets/ship.li/banner.png"


		alias_attribute :email, :contact_person_email



		#scope :active, where(:active => true)

		def address
			address = [self.address_1, self.try(:address_2), "#{self.city} #{self.try(:state)}", "#{self.try(:zip)}"].compact
			address.delete("")
			address.join("<br/>")
		end

		def approve_seller(user)
			self.update_attributes(:active => true)
			add_owner(user)
			create_user 
			create_stock_location
			deliver_approve_email
		end

    def unapprove_seller(user)
			#self.active = false
			self.update_attributes(:active => false)
			add_owner(user)
			self.users.each {|h| h.destroy}
			deliver_unapprove_email
		end

		def add_owner(user)
			self.update_attributes(:owner => user)
		end
	protected

		def deliver_approve_email
      begin
        Spree::ApproveMailer.approve_email(self.id).deliver
      rescue Exception => e
        logger.error("#{e.class.name}: #{e.message}")
        logger.error(e.backtrace * "\n")
      end
    end

		def deliver_unapprove_email
      begin
        Spree::ApproveMailer.unapprove_email(self.id).deliver
      rescue Exception => e
        logger.error("#{e.class.name}: #{e.message}")
        logger.error(e.backtrace * "\n")
      end
    end
		def deliver_welcome_email
      begin
        Spree::ApproveMailer.welcome_email(self.id).deliver
      rescue Exception => e
        logger.error("#{e.class.name}: #{e.message}")
        logger.error(e.backtrace * "\n")
      end
    end

		def fill_simple
			self.roc_number = 10 unless self.roc_number
			self.country_id = 67 unless self.country_id
			self.paypal_account_email = "paypal@pol.com" unless self.paypal_account_email
			self.active = false unless self.active
			self.contact_person_name = "test.person" unless self.contact_person_name
			self.address_1 = "adres 1" unless self.address_1
			self.termsandconditions = true unless self.termsandconditions
			self.city = "test city" unless self.city
			self.phone = "33333" unless self.phone
		end

		def create_user
			role = Role.find_by_name('seller')
			if role.nil?
				Role.create!(:name=> 'seller')
				role = Role.find_by_name('seller')
			end
			generated_password = Devise.friendly_token.first(8)
			#debugger
			#puts self.contact_person_email
			user = Spree::User.new(:email => self.contact_person_email, :password => generated_password)
			#puts(role)
			user.reset_password_sent_at = Time.now
			user.reset_password_token= Spree::User.reset_password_token

			user.spree_roles = [role]
			if user.save!
				self.users << user
			end

		end
		def create_stock_location
			stock = Spree::StockLocation.new(:name => self.name + "default stock", :propagate_all_variants => false)
			#debugger
			stock.seller = self
			stock.save!
		end


	end
end

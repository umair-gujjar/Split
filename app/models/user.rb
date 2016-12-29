# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  username        :string           not null
#  email           :string           not null
#  password_digest :string           not null
#  session_token   :string           not null
#  created_at      :datetime
#  updated_at      :datetime
#

class User < ActiveRecord::Base

  validates :username, :session_token, :password_digest, :email, presence: true
  validates :password, length: { minimum: 6 }, allow_nil: true

  after_initialize :ensure_session_token

  has_many(
    :friendships,
    :class_name => 'Friendship',
    :foreign_key => :user_id,
    :primary_key => :id
  )

  has_many(
    :friends,
    :through => :friendships,
    :source => :friend
  )


  has_many(
    :bills,
    :class_name => 'Bill',
    :foreign_key => :author_id,
    :primary_key => :id
  )


  has_many(
    :received_billsplits,
    :class_name => 'Billsplit',
    :foreign_key => :recipient_id,
    :primary_key => :id
  )


  has_many(
    :bills_received,
    :through => :received_billsplits,
    :source => :bill
  )


  attr_reader :password



  ###########
  # Net_payments method combines the two hashes returned from you_owe and you_are_owed
  # to determine the net amount owed/you owe for each user
  # returns a hash of user: amount where amount is the net between any amount you owe
  # or are owed to a user
  ##########

  def net_payments(current_user_id)
    payments = {"you_are_owed" => {}, "you_owe" => {}}
    # {"Matt"=>15.0, "Sam"=>10.0, "Drew"=>10.0, "Tristan"=>22.22} you_are_owed
    # {"Matt"=>11.11, "Kyle"=>25.22, "Dega"=>30.22, "Drew"=>30.22} you_owe

    you_owe_hash = you_owe(current_user_id)
    you_are_owed_hash = you_are_owed(current_user_id)


    # Find all the uniq keys of the two hashes, then sum the you_are_owed - you_owe, if value is positive, you are owed that amount, if value is negative you owe that amount
    user_payments = you_owe_hash.keys + you_are_owed_hash.keys
    user_payments = user_payments.uniq

    user_payments.each do |user|
      # user is in you_owe_hash and NOT you_are_owed_hash
      if you_owe_hash.has_key?(user) && !you_are_owed_hash.has_key?(user)
        payments["you_owe"][user] = you_owe_hash[user]
      # user is NOT in you_owe_hash and in you_are_owed_hash
      elsif !you_owe_hash.has_key?(user) && you_are_owed_hash.has_key?(user)
        payments["you_are_owed"][user] = you_are_owed_hash[user]
      # user is in both you_owe hash and you_are_owed hash
      else
        amount = (you_are_owed_hash[user] - you_owe_hash[user]).round(2)
        if amount > 0
          # Goes to you are owed
          payments["you_are_owed"][user] = amount

        elsif amount < 0
          # Goes to you owe
          payments["you_owe"][user] = -amount
        end
      end
    end

    payments

  end

  ###########
  # You_owe method creates a hash of user: amount where user are all of the users
  # that the current_user owes by total bill amount
  ###########
  def you_owe(current_user_id)

    you_owe_list = {}
    billsplits = Billsplit.joins(:bill).includes(:bill_author).where('recipient_id = ?', current_user_id).where('recipient_paid = false').where('paid = false')

    billsplits.each do |bill|
      if you_owe_list.has_key? bill.bill_author.username
        temp_amount = you_owe_list[bill.bill_author.username]
        you_owe_list[bill.bill_author.username] = temp_amount + bill.split_amount
      else
        you_owe_list[bill.bill_author.username] = bill.split_amount
      end
    end


    you_owe_list



  end


  ###########
  # You_are_owed method creates a hash of user: amount where user are all of the users
  # that owes the current_user by total bill amount
  ###########
  def you_are_owed(current_user_id)

    you_are_owed_list = {}

    bills = Bill.joins(:bill_splits).joins(:bill_author).where('author_id = ?', current_user_id).where('recipient_paid = false').where('paid = false').includes(:bill_recipients)
    bills.uniq.each do |bill|
      bill.bill_splits.each do |split|
        user = split.recipient.username
        if you_are_owed_list.has_key? user
          temp_amount = you_are_owed_list[user]
          you_are_owed_list[user] = temp_amount + split.split_amount
        else
          you_are_owed_list[user] = split.split_amount
        end
      end
    end

    you_are_owed_list

  end


  ###########
  # Settle_up method finds all billsplits between settle_from user and settle_to user
  # then the method creates a hash with the keys:
  # paid: array of billsplit IDs that need to be updated to paid
  # unpaid: hash where key is the billsplit ID and value is the amount
  # new: a k,v pair where v is the amount of the new bill in the opposite direction
  #
  ###########
  def settle_up(settle_from, settle_to, amount)

    # You are looking for all of the billsplits where the recipient id is payer (settle_from) because those are the ones you want to now fulfill
    billsplits = Billsplit.joins(:bill).where('author_id = ?', settle_to).where('recipient_id = ?', settle_from).where('recipient_paid = false')

    new_bill_settle_list = {"paid" => [], "unpaid" => {}, "new" => 0}

    billsplits.each do |split|
      amount -= split.split_amount
      if amount >= 0
        new_bill_settle_list["paid"].push(split.id)
      else
        unpaid_hash = new_bill_settle_list["unpaid"]
        unpaid_hash[split.id] = -amount.round(2)
        new_bill_settle_list["unpaid"] = unpaid_hash
        break
      end
    end

    if amount > 0
      # No billsplits owed so a new billsplit, bill must be created in the opposite direction
      new_bill_settle_list["new"] = amount.round(2)
    end
    
    new_bill_settle_list

  end


  ###########
  # Bill_paid method updates paid column for Bills. Returns an array
  # of bill_ids that need the paid column to be true
  ###########
  def bill_paid
    bill_ids_to_update = []
    bills = Bill.includes(:bill_splits)

    bill_paid = true
    bills.each do |bill|
      bill.bill_splits.each do |split|
        bill_paid = bill_paid && split.recipient_paid
      end

      if bill_paid
        bill_ids_to_update.push(bill.id)
      end

      # Reset bill_paid back to true for when you go through first billsplit that has a false recipient_paid
      bill_paid = true
    end

    bill_ids_to_update

  end







  ##### USER AUTH METHODS #######

  def self.generate_session_token
    SecureRandom::urlsafe_base64(16)
  end

  def ensure_session_token
    self.session_token ||= User.generate_session_token
  end

  def is_password?(password)
    BCrypt::Password.new(self.password_digest).is_password?(password)
  end

  def password=(password)
    @password = password
    self.password_digest = BCrypt::Password.create(password)
  end

  def reset_session_token!
    self.session_token = User.generate_session_token
    self.save
    self.session_token
  end

  def self.find_by_credentials(username, password)
    user = User.find_by(username: username)
    user && user.is_password?(password) ? user : nil
  end
end

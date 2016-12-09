# == Schema Information
#
# Table name: billsplits
#
#  id             :integer          not null, primary key
#  bill_id        :integer          not null
#  author_id      :integer          not null
#  recipient_id   :integer          not null
#  recipient_paid :boolean          default(FALSE)
#  created_at     :datetime
#  updated_at     :datetime
#

class Billsplit < ActiveRecord::Base

  validates :bill_id, :author_id, :recipient_id, presence: true

  belongs_to(
    :author,
    :class_name => 'User',
    :foreign_key => :author_id,
    :primary_key => :id
  )

  belongs_to(
    :recipient,
    :class_name => 'User',
    :foreign_key => :recipient_id,
    :primary_key => :id
  )

  belongs_to(
    :bill,
    :class_name => 'Bill',
    :foreign_key => :bill_id,
    :primary_key => :id
  )



end
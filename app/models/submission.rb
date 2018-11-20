class Submission < ApplicationRecord
  include AASM

  belongs_to :framework
  belongs_to :supplier
  belongs_to :task

  has_many :files, dependent: :nullify, class_name: 'SubmissionFile'
  has_many :entries, dependent: :nullify, class_name: 'SubmissionEntry'

  aasm do
    state :pending, initial: true
    state :processing
    state :validation_failed
    state :in_review
    state :completed

    event :ready_for_review do
      transitions from: %i[pending processing], to: :in_review, guard: :all_entries_valid?
      transitions from: %i[pending processing], to: :validation_failed
    end

    event :reviewed_and_accepted do
      transitions from: :in_review, to: :completed, guard: :all_entries_valid?

      error do |e|
        errors.add(:aasm_state, message: e.message)
      end
    end
  end

  def all_entries_valid?
    entries.validated.count == entries.count
  end

  def sheet_names
    entries.distinct.pluck(Arel.sql("source->>'sheet'"))
  end

  def report_no_business?
    files.count.zero?
  end
end

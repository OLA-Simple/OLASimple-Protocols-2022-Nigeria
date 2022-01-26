# frozen_string_literal: true

module JobComments
  COMMENT_KEY = 'Technician Comment'

  def accept_comments
    comments = ask_for_comments
    associate_comments_to_operation_and_plan comments unless comments.blank?
  end

  # Associates the comment entered by the lab technician to the operations and plans
  # of the protocol that uses this library.
  #
  # @param [String] the feedback entered by the lab technician.
  def associate_comments_to_operation_and_plan(comments)
    full_comment_key = COMMENT_KEY + "- job #{jid}"

    operations.each do |op|
      op.associate(full_comment_key, comments)
      op.plan.associate(full_comment_key, comments)
    end
  end

  def ask_for_comments
    comment = show do
      title 'Leave Comments'

      note 'If anything out of the ordinary happened during this protocol, make a note of it here.'

      warning 'Be as specific as possible, mentioning names of steps and labels of involved items when appropriate.'
      warning 'Wash hands well before using keyboard or tablet.'

      get 'text', var: 'response_key', label: 'Enter your feedback here', default: ''
    end
    comment[:response_key] # return
  end
end

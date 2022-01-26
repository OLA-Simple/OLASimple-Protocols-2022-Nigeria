module OLAScheduling
  
  SCHEDULER_USER = User.first
  
  # redundant definitions from OLAConstants required to get around precondition limitations
  BATCH_SIZE = 2
  KIT_KEY = :kit
  KIT_PARAMETER = "Kit Identifier"
  
  # retrieve kit id from first input's associations if avialable,
  # also try to retrieve kit id from a kit input parameter if it is available.
  # returns nil if no kit could be found
  def get_kit_id(op)
    op.inputs[0].retrieve
    op.inputs[0].item&.get(KIT_KEY) || op.input(KIT_PARAMETER)&.value
  end
  
  # return if this protocol is being run in developer testing mode 
  def testing_mode?(op)
    op.plan.nil?
  end
  
  # used in place of returning true in precondition
  # gathers together all the other ops with the same kit
  # and schedules them together if they are all ready
  # looks at this_op.inputs[0].item.get(KIT_KEY) to decide what kit an op belongs
  # 
  def schedule_same_kit_ops(this_op)
    return true if testing_mode?(this_op)

    kit_id = get_kit_id(this_op)
    if kit_id.nil?
      this_op.error(:no_kit, "This operation did not have an associated kit id in its input and so couldn't be batched")
      exit
    end
    
    operations = Operation.where({operation_type_id: this_op.operation_type_id, status: ["pending"]})
    this_op.status = "pending"
    this_op.save
    operations << this_op
    operations = operations.to_a.uniq
    operations = operations.select { |op| get_kit_id(op) == kit_id }
    if operations.length == BATCH_SIZE
      Job.schedule(
        operations: operations,
        user: SCHEDULER_USER
      )
    elsif operations.length > BATCH_SIZE
      operations.each do |op|
        op.error(:batch_too_big, "There are too many samples being run with kit #{kit_id}. The Batch size is set to #{BATCH_SIZE}, but there are #{operations.length} operations which list #{kit_id} as their kit association.")
        op.save
        op.plan.error("There are too many samples being run with kit #{kit_id}. The Batch size is set to #{BATCH_SIZE}, but there are #{operations.length} operations which list #{kit_id} as their kit association.", :batch_too_big)
        op.plan.save
      end
    end
    exit
  end
end
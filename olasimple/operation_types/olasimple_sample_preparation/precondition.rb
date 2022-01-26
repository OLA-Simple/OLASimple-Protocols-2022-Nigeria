eval Library.find_by_name("OLAScheduling").code("source").content
extend OLAScheduling

def precondition(_op)
  if _op.plan && _op.plan.status != 'planning'
    schedule_same_kit_ops(_op)
  end
  true
end
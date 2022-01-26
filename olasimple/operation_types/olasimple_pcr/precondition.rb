eval Library.find_by_name("OLAScheduling").code("source").content
extend OLAScheduling

def precondition(op)
  schedule_same_kit_ops(op)
  true
end
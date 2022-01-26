class Protocol

def main
    
    show do
      title "Gather Materials"
      check "Four 14 mL test tubes"
      check "Four different colors of food coloring"
      check "Five 1.5 mL tubes"
    end

    show do
      title "Exercise Preparation"
      note "Fill each test tube about 2/3 full with sink water."
      note "To each test tube add one drop of a different color of food coloring."
      warning "Make sure the blue and purple drops are very small because the color is dark."
      note "Label tubes as I, II, III, and IV."
      note "Put test tubes in a test tube rack and set aside."
    end
    
    show do
      title "Large Volume Exercise"
      note "Take out five 1.5 mL tubes and label them A - E. Put tubes C - D off to the side."
      note "Using the 1 mL pipette, add solution I to the tubes: 100 uL to A and 150 uL to B."
      note "Using the same pipette but a fresh tip, add solution II to the tubes: 200 uL to A and 250 uL to B."
      note "Using the same pipette but a fresh tip, add solution III to the tubes: 150 uL to A and 350 uL to B."
      note "Using the same pipette but a fresh tip, and solution IV to the tubes: 550 uL to A and 250 uL to B."
      check "Each tube should now have 1 mL (total volume) in it, so, to check the error from pipetting, set the 1 mL pipette to 1000 uL and draw up as much liquid as possible from each tube."
    end
    
    calculate_error()
    
    show do
      title "Discard Tubes"
      check "Throw out tubes A and B"
    end
    
    show do 
      title "Small Volume Exercise"
    
      note "Take out tubes C - E, and the 10 uL pipette and pipette tip box."
      note "Add solution I to the tubes: 4 uL in in C, 4 uL in D, and 4 uL in E."
      note "Using the same pipette but a new tip, add solution II to the tubes: 5 uL to C, 5 uL to D, and 4 uL to E."
      note "Using the same pipette but a new tip, add solution III to the tuebs: 1 uL to C, and 1 uL to E."
      note "Using the same pipette but a new tip, add solution IV to the tubes: 1 uL to D and 1 uL to E."
      note "Each tube should now have 10 uL (total volume) in it, so to check the error from pipetting, set the 10 uL pipette to 10 uL and draw up as much liquid as possible from each tube."
    end
    
    calculate_error()
    
    show do
      title "Discard Tubes"
      check "Throw out tubes C, D, and E"
    end
    
    return {}

  end
  
  
  def calculate_error
    choice = show do
      title "Calculate Measurement Error"
      bullet "If there is still liquid left in the tube, too much was added."
      bullet "If there is air at the end of the tip, too little was added."
      bullet "If the tube is filled exactly with liquid, the measurement error is 0."
      
      select ["Too much", "Too little", "Just right"], var: "choice", label: "How much liquid did you add?", default: [0,1,2].sample
    end.get_response("choice")
      
    if choice == "Too much"
      show do
        title "Calculate Measurement Error"
        note "To determine the error if too much was added, follow thise steps:"
        check "Discard the tip with liquid in it and get a fresh tip. "
        check "Carefully pipette up the remaining liquid in the tip, and then rotate the volume dial until the liquid reaches the bottom of the tip." 
        note "The error rate is (new volume / total volume)"
      end
    elsif choice == "Too little"
      show do
        title "Calculate Measurement Error"
        note "To determine the error if too little was added, follow thise steps:"
        check "Slowly decrease the volume until the liquid reaches the end of the tip."
        note "The error rate is ((total volume - new volume) / total volume)"
      end
    else
      show do
        title "Calculate Measurement Error"
        note "If the tube is filled exactly with liquid, the measurement error is 0."
        note "Try again and mess up more so that you can practice calculating measurement error!"
      end
    end
  end
end




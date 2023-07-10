module OLAKits
  def self.rt_pcr()
    {
        "name" => "rt pcr kit",
        "sample prep" => {
            "Unit Name" => "S",
            "Components" => {
                "sample tube" => ""
            }
        },
        "rt module" => {
            "Unit Name" => "RT",
            "Components" => {
                "sample tube" => ""
            }
        },
        "extraction" => {
            "Unit Name" => "E",
            "Components" => {
                "dtt" => "0",
                "lysis buffer" => "1",
                "wash buffer 1" => "2",
                "wash buffer 2" => "3",
                "sodium azide water" => "4",
                "sample column" => "5",
                "rna extract tube" => "6",
            },
            "Number of Samples" => 2,
        },
        "pcr" => {
            "Unit Name" => "A",
            "Components" => {
                "sample tube" => "2",
                "diluent A" => "0"
            },
            "PCR Rehydration Volume" => 40,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2,
        },

        "ligation" => {
            "Unit Name" => "L",
            "Components" => {
                "sample tubes" => [
                    "1",
                    "2",
                    "3",
                    "4",
                    "5",
                    "6",
                    "7",
                    "8",
                    "9",
                    "10"
                ],
                "diluent A" => "0",
                "tubes_blue" => ["blue1", "blue2","blue3", "blue4", "blue5", "blue5", "blue4", "blue3", "blue2", "blue1"],
                "tubes_pink" => ["pink1", "pink2","pink3", "pink4", "pink5", "pink5", "pink4", "pink3", "pink2", "pink1"]
            },
            "PCR to Ligation Mix Volume" => 4,
            "Ligation Mix Rehydration Volume" => 20,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2,
        },

        "detection" => {
            "Unit Name" => "D",
            "Components" => {
                "strips" => [
                    "1",
                    "2",
                    "3",
                    "4",
                    "5",
                    "6",
                    "7",
                    "8",
                    "9",
                    "10"
                ],
                "diluent A" => "0",
                "stop" => "1",
                "gold" => "2"
            },
            "Number of Samples" => 2,
            "Number of Sub Packages" => 4,
            "Stop Rehydration Volume" => 96,
            "Gold Rehydration Volume" => 1032,
            "Gold to Strip Volume" => 40,
            "Sample to Strip Volume" => 24,
            "Stop to Sample Volume" => 4,
            "Sample Volume" => 2.4,
        },
        
        "analysis" => {
             "Mutation Labels" => [
                "M41L", "K65R", "L74I", "K103N", "Y115F", "Y181C", "M184V", "G190A", "T215F/Y", "NC"
            ],
            "Mutation Colors" => ["red", "green","yellow", "blue", "purple", "white", "gray", "red", "green", "yellow"]
        }
    }
  end
end


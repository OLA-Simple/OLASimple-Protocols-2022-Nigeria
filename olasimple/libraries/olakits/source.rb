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
                "diluent A" => "1"
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
                    "7"
                ],
                "diluent A" => "0"
            },
            "PCR to Ligation Mix Volume" => 1.2,
            "Ligation Mix Rehydration Volume" => 24,
            "Number of Samples" => 2,
            "Number of Sub Packages" => 2
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
                    "7"
                ],
                "diluent A" => "0",
                "stop" => "1",
                "gold" => "2"
            },
            "Number of Samples" => 2,
            "Number of Sub Packages" => 4,
            "Stop Rehydration Volume" => 36,
            "Gold Rehydration Volume" => 600,
            "Gold to Strip Volume" => 40,
            "Sample to Strip Volume" => 24,
            "Stop to Sample Volume" => 2.4,
            "Sample Volume" => 2.4,
            "Mutation Labels" => [
                "K65R",
                "70E",
                "K103N",
                "V106M",
                "Y181C",
                "M184V",
                "G190A",
            ],
            "Mutation Colors" => ["red", "green","yellow", "blue", "purple", "white", "gray"]

        }

    }
  end
end
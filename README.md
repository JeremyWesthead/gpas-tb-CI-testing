# gpas-tb-CI-testing
Automated end-to-end testing of the GPAS TB pipeline.

Even without generating samples on each run, this will likely take 4h+ to complete. Each pipeline will likely take 1-1.5h + downloading prerequisites (several GB)

## Testing steps
1. Generate synthetic TB samples with known variations
2. Run these samples through `lodestone` to produce VCF files
3. Run these samples through `gnomon` to produce an antibiogram

## Test cases
Currently there are a few test cases used. Most are derrived from clinical importance (such as XDR samples), but a few edge cases have been included from the WHO TB catalogue
* MDR - Resistant to RIF & INH (`rpoB@S450L`, `katG@S315T`)
* preXDR - MDR & fluoquinolone resistant (`rpoB@S450L`, `gyrA@A90V`, `gyrA@S95T`)
* XDR - preXDR & >=1 of AMI, KAN, CAP resistance (`rpoB@S450L`, `gyrA@A90V`, `gyrA@S95T`, `rplC@C154R`)
* WHO - A wide selection of mutations covering simple SNPs, indels, multi-mutations, revcomp indels, non-coding SNPs etc
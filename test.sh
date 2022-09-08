#!/bin/bash

#As this is to be run using a CI runner, it is assumed that there are minimal tools already present
#Clone and setup the appropriate tools

#Nextflow setup
#Install JDK
curl -s https://get.sdkman.io | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java
#Install Nextflow
curl -s https://get.nextflow.io | bash
chmod a+x nextflow
sudo cp nextflow /usr/local/bin

#Python/pip
python3 -m pip install --upgrade pip

#tb-pipeline (lodestone)
#This also needs kraken and bowtie...
git clone https://github.com/Pathogen-Genomics-Cymru/tb-pipeline.git

#tb-predict-pipeline (gnomon)
git clone https://github.com/oxfordmmm/tb-predict-pipeline.git

#tuberculosis-amr-catalogues (for catalogues)
git clone https://github.com/oxfordmmm/tuberculosis_amr_catalogues.git

#gpas-testing (for generating synthetic samples)
git clone https://github.com/GlobalPathogenAnalysisService/gpas-testing.git

#Generate synthetic samples with known mutations
mkdir syn-illumina-MDR
mkdir syn-illumina-preXDR
mkdir syn-illumina-XDR
mkdir syn-illumina-WHO

cd gpas-testing
#Use a branch with a fix...
git checkout fixMDRMutation
pip install .


#As these take ages, run in parallel
#MDR
tb-synreads --reference ../H37rV_v3.gbk --depth 30 --read_length 300 --variant_file tests/tb-test-lineage4-MDR-rpoB@S450L-katG@S315T.txt  --output ../syn-illumina-MDR/syn-illumina-MDR  --verbose | ts '[%H:%M:%.S]' > MDR.log &

#preXDR
tb-synreads --reference ../H37rV_v3.gbk --depth 30 --read_length 300 --variant_file tests/tb-test-lineage4-preXDR-rpoB@S450L-gyrA@A90V-gyrA@S95T.txt  --output ../syn-illumina-preXDR/syn-illumina-preXDR  --verbose | ts '[%H:%M:%.S]' > preXDR.log &

#XDR
tb-synreads --reference ../H37rV_v3.gbk --depth 30 --read_length 300 --variant_file tests/tb-test-lineage4-XDR-rpoB@S450L-gyrA@A90V-gyrA@S95T-rplC@C154R.txt   --output ../syn-illumina-XDR/syn-illumina-XDR  --verbose | ts '[%H:%M:%.S]' > XDR.log &

#WHO
tb-synreads --reference ../H37rV_v3.gbk --depth 30 --read_length 300 --variant_file tests/tb-resistant-1.txt   --output ../syn-illumina-WHO/syn-illumina-WHO  --verbose | ts '[%H:%M:%.S]' > WHO.log &


FAIL=0

for job in `jobs -p`
do
echo $job
    wait $job || let "FAIL+=1"
done

echo $FAIL

if [ "$FAIL" == "0" ];
then
    echo
    echo "Made synthetics without problems"
    echo 

    #Run the pipelines now we have samples
    #Don't use the `tb-pipeline` gnomon predictions due to version changes
    #TODO: update this when changed
    cd ../tb-pipeline
    export NXF_VER=20.11.0-edge

    #MDR
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-MDR --unmix_myco no --output_dir ../syn-illumina-MDR/  --kraken_db ~/kraken/ --bowtie2_index ~/bowtie2/ --bowtie_index_name hg19_1kgmaj --species tuberculosis --pattern "*{1,2}.fastq" --vcfmix no --gnomon no

    #preXDR
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-preXDR --unmix_myco no --output_dir ../syn-illumina-preXDR/  --kraken_db ~/kraken/ --bowtie2_index ~/bowtie2/ --bowtie_index_name hg19_1kgmaj --species tuberculosis --pattern "*{1,2}.fastq"  --vcfmix no --gnomon no

    #XDR
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-XDR --unmix_myco no --output_dir ../syn-illumina-XDR/  --kraken_db ~/kraken/ --bowtie2_index ~/bowtie2/ --bowtie_index_name hg19_1kgmaj --species tuberculosis --pattern "*{1,2}.fastq" --vcfmix no --gnomon no

    #WHO
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-WHO --unmix_myco no --output_dir ../syn-illumina-WHO/  --kraken_db ~/kraken/ --bowtie2_index ~/bowtie2/ --bowtie_index_name hg19_1kgmaj --species tuberculosis --pattern "*{1,2}.fastq" --vcfmix no --gnomon no

    #Run the prediction pipelines
    cd ..
    baseDir=$(pwd)
    cd tb-predict-pipeline

    #MDR
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-MDR/syn-illumina-MDR/output_vcfs/syn-illumina-MDR.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/tuberculosis_amr_catalogues/catalogues/NC_000962.3/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-MDR

    #preXDR
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-preXDR/syn-illumina-preXDR/output_vcfs/syn-illumina-preXDR.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/tuberculosis_amr_catalogues/catalogues/NC_000962.3/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-preXDR

    #XDR
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-XDR/syn-illumina-XDR/output_vcfs/syn-illumina-XDR.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/tuberculosis_amr_catalogues/catalogues/NC_000962.3/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-XDR

    #WHO
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-WHO/syn-illumina-WHO/output_vcfs/syn-illumina-WHO.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/tuberculosis_amr_catalogues/catalogues/NC_000962.3/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-WHO
else
    echo "Errors with generating synthetics! $FAIL errors detected. See logs"
fi
#!/bin/bash

#As this is to be run using a CI runner, it is assumed that there are minimal tools already present
#Clone and setup the appropriate tools

#Download kraken
mkdir kraken
cd kraken
echo "Downloding Kraken"
curl --progress-bar https://genome-idx.s3.amazonaws.com/kraken/k2_pluspf_16gb_20220607.tar.gz > kraken.tar.gz
tar -xzvf kraken.tar.gz
#Delete the tarball now it has been expanded to save on space
rm kraken.tar.gz
cd ..

echo "Downloading Bowtie2"
mkdir bowtie2
cd bowtie2
curl --progress-bar https://genome-idx.s3.amazonaws.com/bt/hg19.zip > bowtie2.zip
unzip bowtie2.zip
#Remove the zip now it has been expanded to save on space
rm bowtie2.zip
cd ..


#Nextflow setup
#Install JDK
curl -s https://get.sdkman.io | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java
#Install Nextflow
curl -s https://get.nextflow.io | bash
chmod a+x nextflow
sudo cp nextflow /usr/local/bin

echo
echo "*****************"
echo $(df -h /)
echo "*****************"
echo
sudo apt install moreutils

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


#As these take ages, run in parallel (or actually don't due to disk space concerns)
#MDR
tb-synreads --reference ../H37rV_v3.gbk --depth 50 --read_length 300 --variant_file tests/tb-test-lineage4-MDR-rpoB@S450L-katG@S315T.txt  --output ../syn-illumina-MDR/syn-illumina-MDR  --verbose | ts '[%H:%M:%.S]' > MDR.log
gzip ../syn-illumina-MDR/syn-illumina-MDR*

#preXDR
tb-synreads --reference ../H37rV_v3.gbk --depth 50 --read_length 300 --variant_file tests/tb-test-lineage4-preXDR-rpoB@S450L-gyrA@A90V-gyrA@S95T.txt  --output ../syn-illumina-preXDR/syn-illumina-preXDR  --verbose | ts '[%H:%M:%.S]' > preXDR.log
gzip ../syn-illumina-preXDR/syn-illumina-preXDR*


#XDR
tb-synreads --reference ../H37rV_v3.gbk --depth 50 --read_length 300 --variant_file tests/tb-test-lineage4-XDR-rpoB@S450L-gyrA@A90V-gyrA@S95T-rplC@C154R.txt   --output ../syn-illumina-XDR/syn-illumina-XDR  --verbose | ts '[%H:%M:%.S]' > XDR.log
gzip ../syn-illumina-XDR/syn-illumina-XDR*


#WHO
tb-synreads --reference ../H37rV_v3.gbk --depth 50 --read_length 300 --variant_file tests/tb-resistant-1.txt   --output ../syn-illumina-WHO/syn-illumina-WHO  --verbose | ts '[%H:%M:%.S]' > WHO.log
gzip ../syn-illumina-WHO/syn-illumina-WHO*


FAIL=0

# for job in `jobs -p`
# do
# echo $job
#     wait $job || let "FAIL+=1"
# done

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
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-MDR --unmix_myco no --output_dir ../syn-illumina-MDR/  --kraken_db ../kraken/ --bowtie2_index ../bowtie2/ --bowtie_index_name hg19 --species tuberculosis --pattern "*{1,2}.fastq.gz" --vcfmix no --gnomon no

    #preXDR
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-preXDR --unmix_myco no --output_dir ../syn-illumina-preXDR/  --kraken_db ../kraken/ --bowtie2_index ../bowtie2/ --bowtie_index_name hg19 --species tuberculosis --pattern "*{1,2}.fastq.gz"  --vcfmix no --gnomon no

    #XDR
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-XDR --unmix_myco no --output_dir ../syn-illumina-XDR/  --kraken_db ../kraken/ --bowtie2_index ../bowtie2/ --bowtie_index_name hg19 --species tuberculosis --pattern "*{1,2}.fastq.gz" --vcfmix no --gnomon no

    #WHO
    sudo nextflow run main.nf -profile docker --filetype fastq --input_dir ../syn-illumina-WHO --unmix_myco no --output_dir ../syn-illumina-WHO/  --kraken_db ../kraken/ --bowtie2_index ../bowtie2/ --bowtie_index_name hg19 --species tuberculosis --pattern "*{1,2}.fastq.gz" --vcfmix no --gnomon no

    #Run the prediction pipelines
    cd ..
    baseDir=$(pwd)
    cd tb-predict-pipeline

    #MDR
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-MDR/syn-illumina-MDR/output_vcfs/syn-illumina-MDR.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-MDR

    #preXDR
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-preXDR/syn-illumina-preXDR/output_vcfs/syn-illumina-preXDR.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-preXDR

    #XDR
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-XDR/syn-illumina-XDR/output_vcfs/syn-illumina-XDR.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-XDR

    #WHO
    sudo nextflow run . -latest -profile docker --sample $baseDir/syn-illumina-WHO/syn-illumina-WHO/output_vcfs/syn-illumina-WHO.minos.vcf --reference $baseDir/H37rV_v3.gbk --catalogue $baseDir/WHO-UCN-GTB-PCI-2021.7.GARC.csv --output_dir $baseDir/syn-illumina-WHO

    #Testing that the files produced are the same
    cd ..
    #MDR
    echo "MDR variants"
    diff <(sort syn-illumina-MDR/syn-illumina-MDR/syn-illumina-MDR.variants.csv) <(sort expected/syn-illumina-MDR/syn-illumina-MDR.variants.csv)
    echo
    echo "MDR mutations"
    diff <(sort syn-illumina-MDR/syn-illumina-MDR/syn-illumina-MDR.mutations.csv) <(sort expected/syn-illumina-MDR/syn-illumina-MDR.mutations.csv)
    echo
    echo "MDR effects"
    diff <(sort syn-illumina-MDR/syn-illumina-MDR/syn-illumina-MDR.effects.csv) <(sort expected/syn-illumina-MDR/syn-illumina-MDR.effects.csv)
    echo
    
    #preXDR
    echo "preXDR variants"
    diff <(sort syn-illumina-preXDR/syn-illumina-preXDR/syn-illumina-preXDR.variants.csv) <(sort expected/syn-illumina-preXDR/syn-illumina-preXDR.variants.csv)
    echo
    echo "preXDR mutations"
    diff <(sort syn-illumina-preXDR/syn-illumina-preXDR/syn-illumina-preXDR.mutations.csv) <(sort expected/syn-illumina-preXDR/syn-illumina-preXDR.mutations.csv)
    echo
    echo "preXDR effects"
    diff <(sort syn-illumina-preXDR/syn-illumina-preXDR/syn-illumina-preXDR.effects.csv) <(sort expected/syn-illumina-preXDR/syn-illumina-preXDR.effects.csv)
    echo

    #XDR
    echo "XDR variants"
    diff <(sort syn-illumina-XDR/syn-illumina-XDR/syn-illumina-XDR.variants.csv) <(sort expected/syn-illumina-XDR/syn-illumina-XDR.variants.csv)
    echo
    echo "XDR mutations"
    diff <(sort syn-illumina-XDR/syn-illumina-XDR/syn-illumina-XDR.mutations.csv) <(sort expected/syn-illumina-XDR/syn-illumina-XDR.mutations.csv)
    echo
    echo "XDR effects"
    diff <(sort syn-illumina-XDR/syn-illumina-XDR/syn-illumina-XDR.effects.csv) <(sort expected/syn-illumina-XDR/syn-illumina-XDR.effects.csv)
    echo

    #WHO
    echo "WHO variants"
    diff <(sort syn-illumina-WHO/syn-illumina-WHO/syn-illumina-WHO.variants.csv) <(sort expected/syn-illumina-WHO/syn-illumina-WHO.variants.csv)
    echo
    echo "WHO mutations"
    diff <(sort syn-illumina-WHO/syn-illumina-WHO/syn-illumina-WHO.mutations.csv) <(sort expected/syn-illumina-WHO/syn-illumina-WHO.mutations.csv)
    echo
    echo "WHO effects"
    diff <(sort syn-illumina-WHO/syn-illumina-WHO/syn-illumina-WHO.effects.csv) <(sort expected/syn-illumina-WHO/syn-illumina-WHO.effects.csv)
    echo

    #Now make sure the JSONs are the same with a pytest
    pip install pytest recursive_diff
    pytest -vv test_json.py


else
    echo "Errors with generating synthetics! $FAIL errors detected. See logs"
    exit 1
fi

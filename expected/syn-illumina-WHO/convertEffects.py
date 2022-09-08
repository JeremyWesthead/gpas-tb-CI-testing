#Read mutations
with open("syn-illumina-WHO.mutations.csv") as f:
    mutations = [line.strip().split(",") for line in f]
#Read catalogue
with open("../../WHO-UCN-GTB-PCI-2021.7.GARC.csv") as f:
    catalogue = [line.strip() for line in f]

with open("syn-illumina-WHO.effects.csv", "w") as f:
    f.write("UNIQUEID,DRUG,GENE,MUTATION,CATALOGUE_NAME,PREDICTION\n")
    #Find catalogue entries matching mutations
    for row in mutations[1::]:
        mut = row[1]+"@"+row[2]
        results = [r for r in catalogue if mut+"," in r]
        print(mut, results)
        for result in results:
            result = result.split(",")
            drug = result[6]
            pred = result[8]
            f.write(f"syn-illumina-WHO,{drug},{row[1]},{row[2]},WHO-UCN-GTB-PCI-2021.7,{pred}\n")
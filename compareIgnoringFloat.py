'''Due to some of the generated files producing float values where they should be ints,
this script simply truncates the `.0` for a line by line comparison.
Requires 2 arguments: `python compareIgnoringFloat.py <path1> <path2>`
'''
import sys

if __name__ == "__main__":
    f1 = sys.argv[1]
    f2 = sys.argv[2]

    with open(f1) as f:
        f1 = sorted([line.strip().replace(".0","") for line in f])
    
    with open(f2) as f:
        f2 = sorted([line.strip().replace(".0","") for line in f])

    if len(f1) != len(f2):
        print("Different lengths: ", len(f1), len(f2))

    for (a, b) in zip(f1, f2):
        if a != b:
            print(f"{a} | {b}")

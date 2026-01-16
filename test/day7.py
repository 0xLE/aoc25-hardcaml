# Provided for reference

lines = open("day7_input.txt").read().splitlines()

w = len(lines[0])
splitters = [0] * (w + 2)

splits = 0
splitters[lines[0].index("S") + 1] = 1
for line in lines[1:]:
    for i, c in enumerate(line):
        if c == "^" and splitters[i + 1]:
            splitters[i] += splitters[i + 1]
            splitters[i + 2] += splitters[i + 1]
            splitters[i + 1] = 0
            splits += 1

print(sum(splitters))

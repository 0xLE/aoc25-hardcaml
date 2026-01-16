grid = open("day7_input.txt").read().splitlines()

width = len(grid[0])
s_row = None
s_col = None
rows = []

for r, line in enumerate(grid):
    row_bool = []
    for c, char in enumerate(line):
        if char == "S":
            s_row, s_col = r, c
            row_bool.append(False)
        else:
            row_bool.append(char == "^")
    rows.append(row_bool)

print("let width = {} in".format(width))
if s_col is not None:
    print("let s_col = {} in".format(s_col))
print("let rows =")
print("  [")
for i, r in enumerate(rows):
    print(
        "   {}[{}]".format(";" if i != 0 else " ", "; ".join(str(v).lower() for v in r))
    )
print("  ]")

import sys, math
lines = open(sys.argv[1]).read().strip().split('\n')
graph = {}
for line in lines:
    parts = line.split(' -> ')
    graph[parts[0]] = parts[1].split(', ')
res = []
for m in graph['broadcaster']:
    m2 = m
    bin = ''
    while True:
        # decode chains of flip flops as bits in an integer
        g = graph['%'+m2]
        # flip-flops that link to a conjunction are ones
        # everything else is a zero
        bin = ('1' if len(g) == 2 or '%'+g[0] not in graph else '0') + bin
        print(bin, m2)
        # bin = (bin << 1);
    #  if len(g) == 2 or '%'+g[0] not in graph:
    #        bin = bin + 1
        nextl = [next_ for next_ in graph['%'+m2] if '%' + next_ in graph]
        if len(nextl) == 0:
            break
        m2 = nextl[0]
    value = int(bin, 2)
    print(value)
    res += [value]


    #  bin = (bin << 1);
    #  if len(g) == 2 or '%'+g[0] not in graph:
    #        bin = bin + 1
# find least common multiple of integers
print(math.lcm(*res))

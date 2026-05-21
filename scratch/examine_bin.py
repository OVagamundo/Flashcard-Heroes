with open("scratch/item_info_real.bin", "rb") as f:
    data = f.read()

# Print readable strings in it
import string
printable = set(string.printable.encode('ascii'))
current = bytearray()
for b in data:
    if b in printable and b not in [10, 13, 9]: # skip newlines and tabs
        current.append(b)
    else:
        if len(current) >= 4:
            try:
                print(current.decode('ascii'))
            except:
                pass
        current = bytearray()
if len(current) >= 4:
    try:
        print(current.decode('ascii'))
    except:
        pass

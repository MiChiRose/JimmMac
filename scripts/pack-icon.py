import os
import struct
import sys

directory, destination = sys.argv[1:]
chunks = []
for kind, name in [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'),
                   ('icp6', 'icon_32x32@2x.png'), ('ic07', 'icon_128x128.png'),
                   ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'),
                   ('ic10', 'icon_512x512@2x.png')]:
    with open(os.path.join(directory, name), 'rb') as source:
        data = source.read()
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(data) + 8) + data)
payload = b''.join(chunks)
with open(destination, 'wb') as output:
    output.write(b'icns' + struct.pack('>I', len(payload) + 8) + payload)

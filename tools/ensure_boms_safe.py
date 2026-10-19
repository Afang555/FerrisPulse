import os
import glob

def ensure_bom(path):
    with open(path, 'rb') as f:
        data = f.read()
    if not data.startswith(b'\xef\xbb\xbf'):
        with open(path, 'wb') as f:
            f.write(b'\xef\xbb\xbf' + data)
        print('Added BOM to: ' + path)

for root, _, files in os.walk('src'):
    for file in files:
        if file.endswith('.cs'):
            ensure_bom(os.path.join(root, file))

for root, _, files in os.walk('tests'):
    for file in files:
        if file.endswith('.ps1'):
            ensure_bom(os.path.join(root, file))

for root, _, files in os.walk('tools'):
    for file in files:
        if file.endswith('.ps1'):
            ensure_bom(os.path.join(root, file))

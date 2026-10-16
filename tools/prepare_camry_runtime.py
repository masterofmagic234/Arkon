"""Batch the supplied static Camry without changing its triangles or UVs.

Input is the GLB extracted unchanged from the root RAR. The derived runtime
model shares three surfaces (body, rear lenses, front lenses), bakes node
transforms and resamples the supplied 8K textures to 2K for mobile memory.
Requires numpy and Pillow only when preparing the committed asset.
"""
import io
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def prepare(source, destination):
    raw = Path(source).read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    output = bytearray()
    result = {'asset': {'version': '2.0', 'generator': 'Arkon Camry static batching'},
              'bufferViews': [], 'accessors': [], 'buffers': [], 'images': [],
              'textures': [], 'materials': [], 'meshes': [], 'nodes': [],
              'scenes': [{'nodes': [0]}], 'scene': 0}

    def view(data):
        while len(output) % 4:
            output.append(0)
        index = len(result['bufferViews'])
        result['bufferViews'].append({'buffer': 0, 'byteOffset': len(output), 'byteLength': len(data)})
        output.extend(data)
        return index

    def accessor(data, kind, component=5126):
        index = len(result['accessors'])
        entry = {'bufferView': view(data.tobytes()), 'componentType': component,
                 'count': len(data), 'type': kind}
        if kind == 'VEC3':
            entry['min'] = data.min(axis=0).tolist()
            entry['max'] = data.max(axis=0).tolist()
        result['accessors'].append(entry)
        return index

    def read(index):
        entry = doc['accessors'][index]
        v = doc['bufferViews'][entry['bufferView']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[entry['componentType']]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[entry['type']]
        offset = v.get('byteOffset', 0) + entry.get('byteOffset', 0)
        stride = v.get('byteStride', np.dtype(dtype).itemsize * width)
        return np.ndarray((entry['count'], width), dtype=dtype, buffer=binary,
                          offset=offset, strides=(stride, np.dtype(dtype).itemsize)).copy()

    def transform(node):
        if 'matrix' in node:
            return np.array(node['matrix']).reshape(4, 4).T
        x, y, z, w = node.get('rotation', [0, 0, 0, 1])
        rotation = np.array([[1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w],
                             [2*x*y+2*z*w, 1-2*x*x-2*z*z, 2*y*z-2*x*w],
                             [2*x*z-2*y*w, 2*y*z+2*x*w, 1-2*x*x-2*y*y]])
        matrix = np.eye(4)
        matrix[:3, :3] = rotation @ np.diag(node.get('scale', [1, 1, 1]))
        matrix[:3, 3] = node.get('translation', [0, 0, 0])
        return matrix

    groups = {name: [] for name in ['Body', 'RearLenses', 'FrontLenses']}

    def visit(index, parent):
        node = doc['nodes'][index]
        matrix = parent @ transform(node)
        if 'mesh' in node:
            # These are the supplied model's separate lens and reflector parts.
            name = 'RearLenses' if 81 <= index <= 90 or index in [62, 63] else ('FrontLenses' if 67 <= index <= 80 else 'Body')
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                attributes = primitive['attributes']
                position = read(attributes['POSITION'])
                normal = read(attributes['NORMAL']) @ np.linalg.inv(matrix[:3, :3])
                normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-8)
                position = position @ matrix[:3, :3].T + matrix[:3, 3]
                groups[name].append((position, normal, read(attributes['TEXCOORD_0']), read(primitive['indices']).ravel()))
        for child in node.get('children', []):
            visit(child, matrix)

    for node in doc['scenes'][doc.get('scene', 0)]['nodes']:
        visit(node, np.eye(4))

    def texture(image, name):
        buf = io.BytesIO()
        image.save(buf, format='JPEG', quality=95)
        index = len(result['images'])
        # Explicit runtime textures allow deterministic mobile compression and
        # mipmaps, instead of depending on generated embedded-image imports.
        filename = name + '.jpg'
        Path(destination).with_name(filename).write_bytes(buf.getvalue())
        result['images'].append({'uri': filename, 'name': name})
        result['textures'].append({'source': index})
        return index

    originals = []
    for entry in doc['images']:
        v = doc['bufferViews'][entry['bufferView']]
        image = Image.open(io.BytesIO(binary[v.get('byteOffset', 0):v.get('byteOffset', 0)+v['byteLength']])).convert('RGB')
        originals.append(image.resize((2048, 2048), Image.Resampling.LANCZOS))
    normal_id = texture(originals[0], 'camry_normal')
    base_id = texture(originals[1], 'camry_basecolor')
    pixels = np.asarray(originals[1]).astype(np.float32) / 255
    red = (pixels[:, :, 0] > .22) & (pixels[:, :, 0] > pixels[:, :, 1]*1.45) & (pixels[:, :, 0] > pixels[:, :, 2]*1.35)
    white = (pixels.min(axis=2) > .40)
    rear_id = texture(Image.fromarray((pixels * red[:, :, None] * 255).astype(np.uint8)), 'camry_rear_emission')
    front_id = texture(Image.fromarray((pixels * white[:, :, None] * 255).astype(np.uint8)), 'camry_front_emission')
    for name in groups:
        material = {'name': name, 'doubleSided': True, 'normalTexture': {'index': normal_id},
                    'pbrMetallicRoughness': {'baseColorTexture': {'index': base_id}, 'metallicFactor': 0, 'roughnessFactor': .5}}
        if name != 'Body':
            material.update({'emissiveFactor': [1, 1, 1], 'emissiveTexture': {'index': rear_id if name == 'RearLenses' else front_id}})
        result['materials'].append(material)
    primitives = []
    triangles = 0
    for material, (name, parts) in enumerate(groups.items()):
        positions, normals, uvs, indices = [], [], [], []
        offset = 0
        for p, n, uv, ids in parts:
            positions.append(p); normals.append(n); uvs.append(uv); indices.append(ids + offset)
            offset += len(p)
        ids = np.concatenate(indices).astype('<u4')
        triangles += len(ids)//3
        primitives.append({'attributes': {'POSITION': accessor(np.concatenate(positions).astype('<f4'), 'VEC3'),
                                           'NORMAL': accessor(np.concatenate(normals).astype('<f4'), 'VEC3'),
                                           'TEXCOORD_0': accessor(np.concatenate(uvs).astype('<f4'), 'VEC2')},
                           'indices': accessor(ids, 'SCALAR', 5125), 'material': material})
    result['meshes'] = [{'name': 'Camry2018', 'primitives': primitives}]
    result['nodes'] = [{'name': 'Camry2018', 'mesh': 0}]
    result['buffers'] = [{'byteLength': len(output)}]
    header = json.dumps(result, separators=(',', ':')).encode()
    header += b' ' * (-len(header) % 4)
    output += b'\0' * (-len(output) % 4)
    glb = struct.pack('<4sII', b'glTF', 2, 28 + len(header) + len(output)) + struct.pack('<I4s', len(header), b'JSON') + header + struct.pack('<I4s', len(output), b'BIN\0') + output
    Path(destination).write_bytes(glb)
    print(f'{triangles} original triangles, {len(primitives)} shared surfaces, {len(glb)} bytes')


if __name__ == '__main__':
    prepare(*sys.argv[1:3])

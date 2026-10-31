#!/usr/bin/env python3
"""Pin an existing Windows artifact and prove the acceptance harness changes only CI files."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request


def pin(name, pattern):
    value = os.environ.get(name, '')
    assert re.fullmatch(pattern, value), f'Invalid or missing {name}'
    return value


def git(*arguments):
    return subprocess.check_output(['git', *arguments]).decode('utf-8').strip()


def resolve():
    artifact_id = pin('WINDOWS_ARTIFACT_ID', r'[1-9][0-9]*')
    source = pin('WINDOWS_SOURCE_SHA', r'[0-9a-f]{40}')
    tree = pin('WINDOWS_SOURCE_TREE', r'[0-9a-f]{40}')
    checkout = pin('WINDOWS_CHECKOUT_SHA', r'[0-9a-f]{40}')
    repository = pin('GITHUB_REPOSITORY', r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+')
    request = urllib.request.Request(f'https://api.github.com/repos/{repository}/actions/artifacts/{artifact_id}',
        headers={'Authorization':'Bearer ' + os.environ['GH_TOKEN'], 'Accept':'application/vnd.github+json',
                 'X-GitHub-Api-Version':'2022-11-28'})
    with urllib.request.urlopen(request, timeout=30) as response:
        artifact = json.load(response)
    assert str(artifact['id']) == artifact_id and not artifact['expired'], 'Artifact missing or expired'
    assert artifact['name'] == 'AcornHunter-1.58-Windows-x64-' + checkout, 'Artifact checkout/name differs'
    # Actions records the PR head here; github.sha/EXE artifact name may use its
    # synthetic merge checkout. Both commits must have the original source tree.
    assert artifact['workflow_run']['head_sha'] == source, 'Artifact was built from a different source head'
    digest, size, run = artifact['digest'], artifact['size_in_bytes'], artifact['workflow_run']['id']
    assert re.fullmatch(r'sha256:[0-9a-f]{64}', digest) and isinstance(size, int) and size > 0
    assert isinstance(run, int) and run > 0
    return {'artifact-id':artifact_id, 'artifact-run-id':str(run), 'artifact-digest':digest,
            'artifact-bytes':str(size), 'source-sha':source, 'source-tree':tree, 'checkout-sha':checkout,
            'artifact-name':artifact['name'], 'repository':repository}


def allowed(path):
    return path in {'.github/workflows/windows_build.yml', 'docs/windows.md',
                    'tools/desktop_controls157_test.gd', 'tools/desktop_graphics157_test.gd'} or path.startswith('tools/windows157/')


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('mode', choices=['resolve', 'validate'])
parser.add_argument('--report', type=Path)
args = parser.parse_args()
report = resolve()
if args.mode == 'resolve':
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
        for key, value in report.items():
            if key not in ['artifact-name', 'repository']:
                output.write(key + '=' + value + '\n')
else:
    # Pin the original canonical ZIP metadata independently of the new harness.
    for key, environment in [('artifact-run-id','WINDOWS_ARTIFACT_RUN_ID'),
                             ('artifact-digest','WINDOWS_ARTIFACT_DIGEST'),
                             ('artifact-bytes','WINDOWS_ARTIFACT_BYTES')]:
        assert report[key] == os.environ[environment], f'Original artifact {key} changed'
    harness = pin('WINDOWS_HARNESS_SHA', r'[0-9a-f]{40}')
    assert git('rev-parse', 'HEAD') == harness, 'Acceptance harness checkout differs'
    assert git('rev-parse', report['source-sha'] + '^{tree}') == report['source-tree'], 'Original source tree differs'
    assert git('rev-parse', report['checkout-sha'] + '^{tree}') == report['source-tree'], 'Original checkout tree differs'
    changed = subprocess.check_output(['git', 'diff', '--name-only', '-z', '--no-renames', report['source-sha'], harness]).decode('utf-8').split('\0')
    changed = [path for path in changed if path]
    rejected = [path for path in changed if not allowed(path)]
    assert not rejected, f'Cannot reuse the original package after production changes: {rejected}'
    report.update({'harness-sha':harness, 'harness-tree':git('rev-parse','HEAD^{tree}'),
                   'changed-ci-only-paths':changed, 'production-resources-equivalent':True,
                   'scope':'Canonical package source/tree/checkout/digest/size/run pinned separately from current CI-only harness.'})
report['result'] = 'PASS'
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding='utf-8')
print('WINDOWS157 ARTIFACT ' + args.mode.upper() + ': PASS')

"""Run the local, no-API audit from the repository root.

Pass --source PATH to re-extract an export; omit to reuse the local reduced data.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--dart', type=Path)
    args = parser.parse_args()
    dart = args.dart
    if dart is None:
        located = shutil.which('dart')
        if not located:
            parser.error('Dart SDK not found; pass --dart PATH')
        dart = Path(located)
        bundled = dart.parent / 'cache/dart-sdk/bin/dart.exe'
        if bundled.exists():
            dart = bundled
    def run(*command):
        subprocess.run([str(v) for v in command], cwd=ROOT, check=True)
    if args.source:
        run(sys.executable, HERE / 'extract_users.py', args.source.resolve())
    if not (HERE / 'out/users_reduced.jsonl').exists():
        parser.error('No reduced export: provide --source PATH')
    run(sys.executable, HERE / 'build_vectors.py')
    run(dart, '--disable-dart-dev', HERE / 'audit.dart', '--baseline')
    run(dart, '--disable-dart-dev', HERE / 'audit.dart')
    profile = json.loads((HERE / 'out/data_profile.json').read_text(encoding='utf8'))
    before = json.loads((HERE / 'out/baseline_audit.json').read_text(encoding='utf8'))
    after = json.loads((HERE / 'out/updated_audit.json').read_text(encoding='utf8'))
    n = after['cohorts'].get('no_data', {}).get('n', 0)
    unresolved = after['cohorts'].get('no_data', {}).get('top_counts', {}).get('unresolved', 0)
    jitter = after['small_noise_top_retained']
    survey = after['combined_vs_dna_top_agreement']
    travel = after['cohorts'].get('travel_only', {})
    top_counts = {k:v for k,v in travel.get('top_counts', {}).items() if k != 'unresolved'}
    dominant = max(top_counts, key=top_counts.get) if top_counts else None
    summary = {
        'users_audited': profile['counts']['users'],
        'completed_flag_without_responses': profile['counts'].get('complete_flag_but_no_responses',0),
        'actual_response_and_travel_users': profile['counts'].get('dna_and_observed_travel',0),
        'no_data_users': n,
        'no_data_guard_passed': n == unresolved,
        'old_no_data_mean_top_share': before['cohorts'].get('no_data',{}).get('mean_top_share'),
        'new_no_data_mean_top_share': after['cohorts'].get('no_data',{}).get('mean_top_share'),
        'small_noise_top_retention': jitter['same']/jitter['n'] if jitter['n'] else None,
        'combined_and_survey_top_agreement': survey['same']/survey['n'] if survey['n'] else None,
        'travel_only_dominant_type': dominant,
        'travel_only_dominant_fraction': top_counts[dominant]/travel['n'] if dominant else None,
        'no_api_calls': True,
        'validated_persona_accuracy': False,
        'online_ai_axes_tested': False,
        'interpretation': [
            'Missing-data and numerical robustness can be tested with this export.',
            'Type skew remains; generic travel distributions dominate self-reported preferences.',
            'Do not interpret stability, quiz agreement or relative scores as type accuracy.',
            'No production cohort centering or equal-type quota was fitted to this dataset.',
        ],
    }
    (HERE / 'out/validation_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
    print(json.dumps(summary,indent=2))
    if n != unresolved:
        raise SystemExit('No-data recommendation guard failed')


if __name__ == '__main__':
    main()

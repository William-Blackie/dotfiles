"""Exercise secret restoration with a fake CLI, never real secrets."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
chezmoi = shutil.which("chezmoi")
assert chezmoi, "chezmoi is required"
targets = {
    ".kube/config": "private_dot_kube/private_config.tmpl",
    ".config/aws/credentials": "dot_config/private_aws/private_credentials.tmpl",
    ".config/aws/config": "dot_config/private_aws/private_config.tmpl",
}

with tempfile.TemporaryDirectory(prefix="chezmoi-secrets-") as temporary:
    root = Path(temporary)
    source, destination = root / "source", root / "home"
    source.mkdir()
    destination.mkdir()
    shutil.copyfile(repo / ".chezmoiignore", source / ".chezmoiignore")
    shutil.copytree(repo / ".chezmoitemplates", source / ".chezmoitemplates")
    for target, template in targets.items():
        path = source / template
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / template, path)
        path = destination / target
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("existing local value\n")

    fake_op = root / "op"
    fake_op.write_text("""#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
if args[:2] == ['account', 'list']:
    print(json.dumps([{'url': name + '.1password.com', 'account_uuid': letter * 26,
        'user_uuid': 'C' * 26, 'email': 'test@example.com'}
        for name, letter in [('work', 'A'), ('personal', 'B')]]))
    sys.exit(0)
document = args[:2] == ['document', 'get']
assert args[args.index('--account') + 1] == ('B' if document else 'A') * 26, args
if os.environ.get('TEST_OP_FAILURE'): sys.exit(1)
if os.environ.get('TEST_EMPTY'):
    print('   ')
    sys.exit(0)
if document and os.environ.get('TEST_DOCUMENT_FAILURE'): sys.exit(1)
reference = 'homelab' if document else next(a for a in args if a.startswith('op://'))
assert document or 'aws' in reference, 'Work kubeconfig must not be read'
if 'aws' in reference:
    print(os.environ.get('TEST_VALUE', 'resolved') + ' ' + reference)
else:
    config = {'apiVersion': 'v1', 'kind': 'Config', 'current-context': 'default',
        'clusters': [{'name': 'default', 'cluster': {'server': 'https://example.invalid'}}],
        'contexts': [{'name': 'default', 'context': {'cluster': 'default', 'user': 'default', 'namespace': 'test'}}],
        'users': [{'name': 'default', 'user': {'token': os.environ.get('TEST_VALUE', 'resolved') + reference}}]}
    if os.environ.get('TEST_INCOMPLETE'): config['users'] = []
    print(json.dumps(config))
""")
    fake_op.chmod(0o755)
    config = root / "chezmoi.toml"
    base_config = (
        "[onepassword]\n"
        f"command = {json.dumps(str(fake_op))}\n"
        'account = "personal.1password.com"\n'
        "prompt = false\n"
    )
    aws = """
[data.workSecrets]
account = "work.1password.com"
awsCredentials = "op://vault/aws/notesPlain"
awsConfig = "op://vault/aws/config"
"""
    legacy_kubernetes = """
[data.kubernetes]
currentContext = "prod"
[[data.kubernetes.sources]]
name = "prod"
account = "work.1password.com"
reference = "op://vault/prod/notesPlain"
[[data.kubernetes.sources]]
name = "staging"
account = "work.1password.com"
reference = "op://vault/staging/notesPlain"
"""
    other_work_context = """
[[data.kubernetes.sources]]
name = "another-work-context"
account = "work.1password.com"
reference = "op://vault/another-work-context/notesPlain"
"""
    homelab = """
[[data.kubernetes.sources]]
name = "homelab"
account = "personal.1password.com"
document = "homelab"
vault = "homelab"
"""
    command = [
        chezmoi,
        "--source",
        str(source),
        "--destination",
        str(destination),
        "--config",
        str(config),
        "--cache",
        str(root / "cache"),
        "--persistent-state",
        str(root / "state"),
        "--no-tty",
        "apply",
        "--force",
        "--include=files",
    ]
    config.write_text(base_config)
    result = subprocess.run(command, capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
    assert all(
        (destination / t).read_text() == "existing local value\n" for t in targets
    )

    config.write_text(base_config + legacy_kubernetes)
    result = subprocess.run(command, capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
    assert (destination / ".kube/config").read_text() == "existing local value\n"
    mappings = aws + legacy_kubernetes + other_work_context + homelab
    config.write_text(base_config + mappings)
    # The init template preserves local mappings without managing its own config.
    result = subprocess.run(
        command[:-3]
        + ["execute-template", "--init", "--file", str(repo / ".chezmoi.toml.tmpl")],
        env={
            key: value for key, value in os.environ.items() if not key.startswith("OP_")
        },
        capture_output=True,
    )
    assert result.returncode == 0, result.stderr.decode()
    # Use chezmoi's parser so these tests also run with Python 3.10.
    configs = []
    for toml_source in (result.stdout, mappings.encode()):
        parsed = subprocess.run(
            command[:-3]
            + [
                "execute-template",
                "--with-stdin",
                "{{ .chezmoi.stdin | fromToml | toJson }}",
            ],
            input=toml_source,
            capture_output=True,
        )
        assert parsed.returncode == 0, parsed.stderr.decode()
        configs.append(json.loads(parsed.stdout))
    rendered, original = configs
    assert rendered["data"] == original["data"]
    assert set(rendered["hooks"]) == {"read-source-state"}
    assert rendered["diff"]["exclude"] == rendered["status"]["exclude"] == ["scripts"]

    for target in (".config/aws/config", ".config/aws/credentials"):
        for failure in ("TEST_OP_FAILURE", "TEST_EMPTY"):
            result = subprocess.run(
                command + [str(destination / target)],
                env=dict(os.environ, **{failure: "1"}),
                capture_output=True,
            )
            assert result.returncode != 0, "Failed or empty AWS reads must fail apply"
            assert (destination / target).read_text() == "existing local value\n"

    for failure in (
        "TEST_OP_FAILURE",
        "TEST_INCOMPLETE",
        "TEST_EMPTY",
        "TEST_DOCUMENT_FAILURE",
    ):
        # Target only kubeconfig: a failure must never replace that file.
        result = subprocess.run(
            command + [str(destination / ".kube/config")],
            env=dict(os.environ, **{failure: "1"}),
            capture_output=True,
        )
        assert result.returncode != 0, "Invalid source must fail apply"
        assert (destination / ".kube/config").read_text() == "existing local value\n"

    for invalid in (
        mappings + homelab,
        mappings.replace('currentContext = "prod"', 'currentContext = "missing"'),
        mappings.replace(
            'document = "homelab"', 'document = "homelab"\nreference = "op://invalid"'
        ),
    ):
        config.write_text(base_config + invalid)
        result = subprocess.run(
            command + [str(destination / ".kube/config")], capture_output=True
        )
        assert result.returncode != 0, "Invalid mappings must fail apply"
        assert (destination / ".kube/config").read_text() == "existing local value\n"
    config.write_text(base_config + mappings)

    for value in ("resolved", "updated"):
        result = subprocess.run(
            command, env=dict(os.environ, TEST_VALUE=value), capture_output=True
        )
        assert result.returncode == 0, result.stderr.decode()
        for target in targets:
            assert (destination / target).stat().st_mode & 0o777 == 0o600
        for target, reference in [("credentials", "notesPlain"), ("config", "config")]:
            assert (
                destination / ".config/aws" / target
            ).read_text() == f"{value} op://vault/aws/{reference}\n"
        # Parse using kubectl without contacting any cluster.
        result = subprocess.run(
            [
                "kubectl",
                "--kubeconfig",
                str(destination / ".kube/config"),
                "config",
                "view",
                "--raw",
                "-o",
                "json",
            ],
            capture_output=True,
        )
        assert result.returncode == 0, result.stderr.decode()
        merged = json.loads(result.stdout)
        assert merged["current-context"] == "homelab"
        for section in ("contexts", "clusters", "users"):
            assert [entry["name"] for entry in merged[section]] == ["homelab"]
        for entry in merged["contexts"]:
            assert entry["context"] == {
                "cluster": entry["name"],
                "user": entry["name"],
                "namespace": "test",
            }
        assert all(
            entry["user"]["token"].startswith(value) for entry in merged["users"]
        )

print("Secret tests passed: homelab, AWS, refresh, permissions, failure safety")

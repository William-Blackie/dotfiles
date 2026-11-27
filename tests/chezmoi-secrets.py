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
    ".config/aws/credentials": "dot_config/private_aws/private_credentials.tmpl",
    ".config/aws/config": "dot_config/private_aws/private_config.tmpl",
}

with tempfile.TemporaryDirectory(prefix="chezmoi-secrets-") as temporary:
    root = Path(temporary)
    source, destination = root / "source", root / "home"
    source.mkdir()
    destination.mkdir()
    shutil.copyfile(repo / ".chezmoiignore", source / ".chezmoiignore")
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
assert args[args.index('--account') + 1] == 'A' * 26, args
if os.environ.get('TEST_OP_FAILURE'): sys.exit(1)
if os.environ.get('TEST_EMPTY'):
    print('   ')
    sys.exit(0)
reference = next(a for a in args if a.startswith('op://'))
print(os.environ.get('TEST_VALUE', 'resolved') + ' ' + reference)
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

    config.write_text(base_config + aws)
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
    for toml_source in (result.stdout, aws.encode()):
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

print("Secret tests passed: AWS, refresh, permissions, failure safety")

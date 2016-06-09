#!/usr/bin/env python
#
# Nim CI starter. Runs as a cronjob or manually; Instructs CircleCI to start
# a build + test cycle.when needed.
#
# Copyright 2016 Federico Ceratto <federico.ceratto@gmail.com>
# Released under GPLv3 License, see LICENSE file

from argparse import ArgumentParser
import json
import os.path
import requests

this_proj = 'FedericoCeratto/nim-ci'
this_proj_branch = 'master'
circleci_token_fname = "~/.circleci_nim_token"
trigger_build_url_tpl = "https://circleci.com/api/v1/project/%(project)s/tree/%(branch)s?circle-token=%(token)s"  # noqa
nim_commit_url = "https://api.github.com/repos/nim-lang/Nim/git/refs/heads/devel"  # noqa
nimble_commit_url = "https://api.github.com/repos/nim-lang/Nimble/git/refs/heads/master"  # noqa
pkgs_commit_url = "https://api.github.com/repos/nim-lang/packages/git/refs/heads/master"  # noqa
status_fn = os.path.expanduser("~/.nimci_cronjob.json")


# Cronjob example:
# 30 * * * *  <this_script> | /usr/bin/logger


def load_status():
    try:
        with open(status_fn) as f:
            return json.load(f)
    except IOError:
        return dict(nim_commit=None, nimble_commit=None, pkgs_commit=None)


def save_status(st):
    with open(status_fn, 'w') as f:
        json.dump(st, f)


def fetch_last_commit(url):
    r = requests.get(url)
    return r.json()['object']['sha']


def load_token():
    with open(os.path.expanduser(circleci_token_fname)) as f:
        return f.read().strip()


def start_build(rebuild_nim=False):
    """Start build on CircleCI
    """
    token = load_token()
    trigger_build_url = trigger_build_url_tpl % dict(
        project=this_proj, branch=this_proj_branch, token=token)
    print(trigger_build_url)
    return

    params = {
        "build_parameters": {
            "RUN_NIGHTLY_BUILD": "true",
            "REBUILD_NIM": str(rebuild_nim).lower(),
            "foo": "bar",
        }
    }
    params = json.dumps(params)
    r = requests.post(trigger_build_url, data=params)
    j = r.json()
    if r.status_code == requests.codes.created:
        print("nim_test_cronjob: build started, %s" % j["build_url"])
        print(json.dumps(r.json(), indent=2))

    else:
        print("nim_test_cronjob: build start failed: %s %r" % (
            r.status_code, j))


def parse_args():
    ap = ArgumentParser()
    ap.add_argument('--nim', action='store_true', default=False,
                    help='Always rebuild Nim and run its tests')
    ap.add_argument('--install-test', action='store_true', default=False,
                    help='Always perform the Nimble install test')
    return ap.parse_args()


def main():
    args = parse_args()
    if not args.nim:
        status = load_status()
        # rebuild Nim only if needed
        last_nim_commit = fetch_last_commit(nim_commit_url)
        last_nimble_commit = fetch_last_commit(nimble_commit_url)
        if status['nim_commit'] != last_nim_commit or \
                status['nimble_commit'] != last_nimble_commit:
            print("Nim or Nimble change detected")
            args.nim = True
            status['nim_commit'] = last_nim_commit
            status['nimble_commit'] = last_nimble_commit
            save_status(status)

    if not args.install_test:
        last_pkgs_commit = fetch_last_commit(pkgs_commit_url)
        if status['pkgs_commit'] != last_pkgs_commit:
            print("Packages change detected")
            args.install_test = True
            status['pkgs_commit'] = last_pkgs_commit
            save_status(status)
        elif args.nim:
            args.install_test = True

    if args.install_test:
        start_build(rebuild_nim=args.nim)


main()

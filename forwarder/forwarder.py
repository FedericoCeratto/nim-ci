#!/usr/bin/env python

import requests
from bottle import route
import bottle
import time


CIRCLECI_API_LAST_BUILD = 'https://circleci.com/api/v1/project/FedericoCeratto/nim-ci'  # noqa
TPL = "https://circle-artifacts.com/gh/FedericoCeratto/nim-ci/%d/artifacts/0/home/ubuntu/nim-ci/output/"  # noqa
circleci_build_caching_time = 30

last_circleci_build_path = None
last_circleci_build_path_update_time = None


def refresh_build_num():
    global last_circleci_build_path, last_circleci_build_path_update_time
    now = time.time()
    if last_circleci_build_path is None or \
            last_circleci_build_path_update_time < now - circleci_build_caching_time:  # noqa
        r = requests.get(CIRCLECI_API_LAST_BUILD).json()
        for build in r:
            if build["status"] == "success" and build["has_artifacts"]:
                last_build_num = build['build_num']
                last_circleci_build_path = TPL % last_build_num
                last_circleci_build_path_update_time = now
                print("Last successful build: %d" % last_build_num)
                return


def redirect(url):
    bottle.redirect(url, 307)


def help():
    return """
<html><body><p>
Allowed paths:<br/>
  / - install report <br/>
  /<pkgname>/version.svg - package version <br/>
  /<pkgname>/nimdevel/status.svg - package status <br/>
  /<pkgname>/nimdevel/output.html - package status output <br/>
  /<pkgname>/nimstable/status.svg - package status <br/>
  /<pkgname>/nimstable/output.html - package status output <br/>
</p></body></html>
"""


@route('/')
def install_report():
    refresh_build_num()
    redirect(last_circleci_build_path + 'nimble_install_report.html')


@route('/<pkg_name>/version.svg')
def version(pkg_name):
    refresh_build_num()
    redirect(last_circleci_build_path + '%s/version.svg' % pkg_name)


@route('/<pkg_name>/<nim_version>/<artifact>')
def install_report_for_one_package(pkg_name, nim_version, artifact):
    refresh_build_num()
    if nim_version not in ('nimstable', 'nimdevel') or \
            artifact not in ('status.svg', 'output.html'):
        return help()

        redirect(last_circleci_build_path + '%s.svg' % pkg_name)


@route('/help')
def serve_help():
    return help()

refresh_build_num()
bottle.run(host='localhost', port=8702)
